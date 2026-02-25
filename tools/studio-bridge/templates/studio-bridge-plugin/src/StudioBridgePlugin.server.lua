--[[
	StudioBridge unified plugin entry point — Layer 2 Roblox glue.

	Supports two boot modes:
	  - Ephemeral: build constants substituted by the CLI, connects directly.
	  - Persistent: template strings intact, uses DiscoveryStateMachine to
	    scan ports and auto-connect to a running studio-bridge server.

	All protocol logic, state machine logic, action routing, and message
	buffering live in Layer 1 modules under Shared/. This file is thin
	glue that wires those modules to Roblox services.
]]

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

-- Layer 1 modules (pure logic, no Roblox deps)
local ActionRouter = require(script.Parent.Shared.ActionRouter)
local DiscoveryStateMachine = require(script.Parent.Shared.DiscoveryStateMachine)
local MessageBuffer = require(script.Parent.Shared.MessageBuffer)

-- Actions are pushed dynamically over the wire via registerAction.
-- No static action requires needed.

-- Build constants (Handlebars templates substituted at build time)
local PORT = "{{PORT}}"
local SESSION_ID = "{{SESSION_ID}}"
local IS_EPHEMERAL = ("{{EPHEMERAL}}" == "true")

-- Only run inside Studio edit context. Plugin instances spawned by play
-- mode (client/server) cannot make HTTP requests, so they cannot discover
-- the bridge. The edit-context instance stays alive during play mode.
if not RunService:IsStudio() or RunService:IsRunning() then
	return
end

-- ---------------------------------------------------------------------------
-- Context detection
-- ---------------------------------------------------------------------------

local function detectContext()
	if RunService:IsRunning() then
		if RunService:IsClient() then
			return "client"
		else
			return "server"
		end
	end
	return "edit"
end

-- ---------------------------------------------------------------------------
-- Instance / session ID helpers
-- ---------------------------------------------------------------------------

-- Short unique nonce for disambiguating unpublished places with the same name.
-- Generated once per plugin lifecycle so the session ID stays stable across reconnects.
local _nonce: string = string.sub(HttpService:GenerateGUID(false), 1, 8)

local function getInstanceId()
	if game.GameId ~= 0 or game.PlaceId ~= 0 then
		return `{game.GameId}-{game.PlaceId}`
	end
	-- Unpublished place: use sanitized place name + nonce for uniqueness
	local name = string.lower(game.Name or "untitled")
	name = string.gsub(name, "%s+", "-")
	name = string.gsub(name, "[^%w%-]", "")
	if name == "" then
		name = "untitled"
	end
	return `local-{name}-{_nonce}`
end

local function getSessionId()
	return `{getInstanceId()}-{detectContext()}`
end

-- ---------------------------------------------------------------------------
-- JSON helpers (HttpService wrappers for Roblox environment)
-- ---------------------------------------------------------------------------

local function jsonEncode(tbl)
	return HttpService:JSONEncode(tbl)
end

local function jsonDecode(raw)
	local ok, result = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok then
		return result
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Shared state
-- ---------------------------------------------------------------------------

local router = ActionRouter.new()
local logBuffer = MessageBuffer.new(1000)

-- Pre-load the PNG encoder and expose it to dynamically loaded actions
-- via router._vendorPng. The screenshot action reads this in its register().
local _pngOk, _pngModule = pcall(function()
	return require(script.Parent.Vendor.png)
end)
if _pngOk and _pngModule then
	router._vendorPng = _pngModule
end

-- Wire outgoing messages (set after WebSocket is connected)
local sendMessageFn = nil

-- Callback that forwards messages through the active WebSocket
local function sendMessage(msg)
	if sendMessageFn then
		sendMessageFn(msg)
	end
end

-- Register the built-in registerAction handler. This allows the bridge
-- server to push Luau action modules over the wire after a plugin connects.
router:register("registerAction", function(payload, requestId, sessionId)
	local name = payload.name
	local source = payload.source
	local responseType = payload.responseType

	if type(name) ~= "string" or type(source) ~= "string" then
		return {
			name = name or "unknown",
			success = false,
			error = "Invalid registerAction payload: name and source are required strings",
		}
	end

	local success, err = router:registerAction(name, source, sendMessage, logBuffer, responseType)
	return {
		name = name,
		success = success,
		error = err,
	}
end)
router:setResponseType("registerAction", "registerActionResult")

local connected = false

local LEVEL_MAP = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

-- Hybrid clock: os.time() for absolute wall-clock, os.clock() deltas for sub-second precision
local clockBase = os.clock()
local timeBase = os.time()

-- Capture logs from the moment the plugin loads, regardless of WebSocket state
LogService.MessageOut:Connect(function(message, messageType)
	if string.sub(message, 1, 14) == "[StudioBridge]" then
		return
	end
	logBuffer:push({
		level = LEVEL_MAP[messageType] or "Print",
		body = message,
		timestamp = timeBase + (os.clock() - clockBase),
	})
end)

-- ---------------------------------------------------------------------------
-- Wire a WebSocket connection
-- ---------------------------------------------------------------------------

local function wireConnection(ws, sessionId, connectLabel)
	connected = true

	-- Wire the sendMessage callback for action handlers
	sendMessageFn = function(msg)
		pcall(function()
			ws:Send(jsonEncode(msg))
		end)
	end

	-- Send register message
	ws:Send(jsonEncode({
		type = "register",
		protocolVersion = 2,
		sessionId = sessionId,
		payload = {
			pluginVersion = "0.7.0",
			instanceId = getInstanceId(),
			context = detectContext(),
			placeName = game.Name or "Unknown",
			placeId = game.PlaceId,
			gameId = game.GameId,
			state = "ready",
			capabilities = {
				"execute",
				"queryState",
				"queryDataModel",
				"queryLogs",
				"captureScreenshot",
				"subscribe",
				"heartbeat",
				"registerAction",
			},
		},
	}))

	-- Incoming messages -> ActionRouter dispatch
	ws.MessageReceived:Connect(function(rawData)
		local msg = jsonDecode(rawData)
		if not msg or type(msg.type) ~= "string" then
			return
		end

		if msg.type == "welcome" or msg.type == "shutdown" then
			if msg.type == "shutdown" then
				connected = false
				pcall(function()
					ws:Close()
				end)
			end
			return
		end

		local response = router:dispatch(msg)
		if response then
			ws:Send(jsonEncode(response))
		end
	end)

	ws.Closed:Connect(function()
		connected = false
	end)

	-- Heartbeat coroutine
	task.spawn(function()
		while connected do
			pcall(function()
				ws:Send(jsonEncode({ type = "heartbeat", sessionId = sessionId, payload = {} }))
			end)
			task.wait(15)
		end
	end)

	print(`[StudioBridge] Connected to {connectLabel} as {sessionId}`)
end

-- ---------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------

if IS_EPHEMERAL then
	-- Ephemeral mode: CLI substituted PORT and SESSION_ID, connect directly
	local wsUrl = `ws://localhost:{PORT}/{SESSION_ID}`
	local ok, ws = pcall(function()
		return HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, { Url = wsUrl })
	end)
	if ok and ws then
		ws.Opened:Connect(function()
			wireConnection(ws, SESSION_ID, `localhost:{PORT} (ephemeral)`)
		end)
		ws.Error:Connect(function(status, err)
			warn(`[StudioBridge] WebSocket error ({status}): {err}`)
		end)
	else
		warn("[StudioBridge] Failed to create WebSocket client")
	end
else
	-- Persistent mode: discover server via port scanning
	local POLL_INTERVAL_SEC = 2

	-- Forward-declare so closures inside the callback table can reference it.
	local discovery
	discovery = DiscoveryStateMachine.new(nil, {
		scanPortsAsync = function(ports, timeoutSec)
			-- Scan all ports in parallel using task.spawn. The calling thread
			-- yields and is resumed as soon as any port succeeds, all fail,
			-- or the timeout expires. Use task.defer (not task.spawn) to resume
			-- the caller so it has time to reach coroutine.yield() first.
			local callerThread = coroutine.running()
			local foundPort = nil
			local foundBody = nil
			local remaining = #ports
			local settled = false
			local threads = {}

			for _, port in ports do
				local thread = task.spawn(function()
					local url = `http://localhost:{port}/health`
					local ok2, body = pcall(HttpService.GetAsync, HttpService, url)
					if ok2 and not settled then
						foundPort = port
						foundBody = body
						settled = true
						task.defer(callerThread)
						return
					end
					remaining -= 1
					if remaining <= 0 and not settled then
						settled = true
						task.defer(callerThread)
					end
				end)
				table.insert(threads, thread)
			end

			-- Timeout: use the deadline from the poll loop
			local timeoutThread = task.delay(timeoutSec, function()
				if not settled then
					settled = true
					task.defer(callerThread)
				end
			end)

			coroutine.yield()

			-- Cancel remaining HTTP threads and the timeout
			pcall(task.cancel, timeoutThread)
			for _, thread in threads do
				pcall(task.cancel, thread)
			end

			return foundPort, foundBody
		end,
		connectWebSocket = function(url)
			local ok2, ws = pcall(function()
				return HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, { Url = url })
			end)
			return ok2, ws
		end,
		onStateChange = function(oldState, newState)
			if newState == "searching" and oldState == "idle" then
				print("[StudioBridge] Searching for host on ports 38741-38744...")
			end
		end,
		onConnected = function(ws, port)
			local sessionId = getSessionId()
			ws.Opened:Connect(function()
				wireConnection(ws, sessionId, `localhost:{port}`)
			end)
			ws.Error:Connect(function(status, err)
				warn(`[StudioBridge] WebSocket error ({status}): {err}`)
			end)
			ws.Closed:Connect(function()
				connected = false
				discovery:onDisconnect("closed")
			end)
		end,
		onDisconnected = function(reason)
			connected = false
			print(`[StudioBridge] Disconnected ({reason}), searching...`)
		end,
	})
	print(`[StudioBridge] Session ID: {getSessionId()}`)
	discovery:start()

	-- Drive the state machine with a simple polling loop.
	-- Each iteration has a fixed time budget (POLL_INTERVAL_SEC). The
	-- remaining time threads through pollAsync → scanPortsAsync so all
	-- async operations complete within the budget.
	task.spawn(function()
		while true do
			local startTime = os.clock()
			discovery:pollAsync(POLL_INTERVAL_SEC)
			-- Sleep for the remainder of the cycle
			local elapsed = os.clock() - startTime
			local remaining = POLL_INTERVAL_SEC - elapsed
			if remaining > 0 then
				task.wait(remaining)
			else
				task.wait() -- yield at least one frame
			end
		end
	end)
end
