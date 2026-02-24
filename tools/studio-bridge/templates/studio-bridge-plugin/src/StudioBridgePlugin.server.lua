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
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")

-- Layer 1 modules (pure logic, no Roblox deps)
local ActionRouter = require(script.Parent.Shared.ActionRouter)
local DiscoveryStateMachine = require(script.Parent.Shared.DiscoveryStateMachine)
local MessageBuffer = require(script.Parent.Shared.MessageBuffer)

-- Actions
local ExecuteAction = require(script.Parent.Actions.ExecuteAction)

-- Build constants (Handlebars templates substituted at build time)
local PORT = "{{PORT}}"
local SESSION_ID = "{{SESSION_ID}}"
local IS_EPHEMERAL = ("{{EPHEMERAL}}" == "true")

-- Only run inside Studio
if not RunService:IsStudio() then
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

local function getInstanceId()
	if game.GameId ~= 0 or game.PlaceId ~= 0 then
		return tostring(game.GameId) .. "-" .. tostring(game.PlaceId)
	end
	-- Unpublished place: use sanitized place name for readability
	local name = string.lower(game.Name or "untitled")
	name = string.gsub(name, "%s+", "-")
	name = string.gsub(name, "[^%w%-]", "")
	if name == "" then
		name = "untitled"
	end
	return "local-" .. name
end

local function getSessionId()
	return getInstanceId() .. "-" .. detectContext()
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

-- Wire outgoing messages (set after WebSocket is connected)
local sendMessageFn = nil

-- Register action handlers
ExecuteAction.register(router, function(msg)
	if sendMessageFn then
		sendMessageFn(msg)
	end
end)

local logBuffer = MessageBuffer.new(1000)
local connected = false

local LEVEL_MAP = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

-- ---------------------------------------------------------------------------
-- Wire a WebSocket connection
-- ---------------------------------------------------------------------------

local function wireConnection(ws, sessionId)
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
			capabilities = { "execute", "queryState", "queryLogs" },
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
				pcall(function() ws:Close() end)
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

	-- Capture logs into buffer
	LogService.MessageOut:Connect(function(message, messageType)
		if string.sub(message, 1, 14) == "[StudioBridge]" then
			return
		end
		logBuffer:push({
			level = LEVEL_MAP[messageType] or "Print",
			body = message,
			timestamp = os.clock(),
		})
	end)

	print("[StudioBridge] Connected (context: " .. detectContext() .. ")")
end

-- ---------------------------------------------------------------------------
-- Boot
-- ---------------------------------------------------------------------------

if IS_EPHEMERAL then
	-- Ephemeral mode: CLI substituted PORT and SESSION_ID, connect directly
	local wsUrl = "ws://localhost:" .. PORT .. "/" .. SESSION_ID
	local ok, ws = pcall(function()
		return HttpService:CreateWebStreamClient(
			Enum.WebStreamClientType.WebSocket, { Url = wsUrl }
		)
	end)
	if ok and ws then
		ws.Opened:Connect(function()
			wireConnection(ws, SESSION_ID)
		end)
		ws.Error:Connect(function(status, err)
			warn("[StudioBridge] WebSocket error (" .. tostring(status) .. "): " .. tostring(err))
		end)
	else
		warn("[StudioBridge] Failed to create WebSocket client")
	end
else
	-- Persistent mode: discover server via port scanning
	-- Forward-declare so closures inside the callback table can reference it.
	local discovery
	discovery = DiscoveryStateMachine.new(nil, {
		httpGet = function(url)
			local ok2, body = pcall(HttpService.GetAsync, HttpService, url)
			return ok2, body
		end,
		scanPorts = function(ports)
			-- Scan all ports in parallel using task.spawn. The calling thread
			-- yields and is resumed as soon as any port succeeds or all fail.
			local callerThread = coroutine.running()
			local foundPort = nil
			local foundBody = nil
			local remaining = #ports
			local settled = false
			local threads = {}

			for _, port in ports do
				local thread = task.spawn(function()
					local url = "http://localhost:" .. tostring(port) .. "/health"
					local ok2, body = pcall(HttpService.GetAsync, HttpService, url)
					if ok2 and not settled then
						foundPort = port
						foundBody = body
						settled = true
						task.spawn(callerThread)
						return
					end
					remaining = remaining - 1
					if remaining <= 0 and not settled then
						settled = true
						task.spawn(callerThread)
					end
				end)
				table.insert(threads, thread)
			end

			if not settled then
				coroutine.yield()
			end

			-- Cancel remaining requests
			for _, thread in threads do
				pcall(task.cancel, thread)
			end

			return foundPort, foundBody
		end,
		connectWebSocket = function(url)
			local ok2, ws = pcall(function()
				return HttpService:CreateWebStreamClient(
					Enum.WebStreamClientType.WebSocket, { Url = url }
				)
			end)
			return ok2, ws
		end,
		onStateChange = function(oldState, newState)
			print("[StudioBridge] " .. oldState .. " -> " .. newState)
		end,
		onConnected = function(ws)
			local sessionId = getSessionId()
			ws.Opened:Connect(function()
				wireConnection(ws, sessionId)
			end)
			ws.Error:Connect(function(status, err)
				warn("[StudioBridge] WebSocket error (" .. tostring(status) .. "): " .. tostring(err))
				discovery:onDisconnect("error: " .. tostring(status))
			end)
			ws.Closed:Connect(function()
				connected = false
				discovery:onDisconnect("closed")
			end)
		end,
		onDisconnected = function(reason)
			connected = false
			print("[StudioBridge] Disconnected: " .. tostring(reason))
		end,
	})
	discovery:start()

	-- Drive the state machine from RunService.Heartbeat.
	-- Reentrancy guard: httpGet yields (GetAsync), so a second Heartbeat can
	-- fire while a tick is still in progress. Without the guard, multiple
	-- overlapping scans find the same server and each opens its own WebSocket.
	local lastTick = os.clock()
	local ticking = false
	RunService.Heartbeat:Connect(function()
		if ticking then
			return
		end
		ticking = true
		local now = os.clock()
		local deltaMs = (now - lastTick) * 1000
		lastTick = now
		discovery:tick(deltaMs)
		ticking = false
	end)
end
