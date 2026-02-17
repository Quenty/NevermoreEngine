--[[
	StudioBridge plugin — injected at runtime by @quenty/studio-bridge.

	Connects to a local WebSocket server, streams LogService output, and
	executes embedded Luau scripts. Template placeholders are substituted
	by the Node.js side before writing this file to the Studio plugins folder.
]]

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PORT = "{{PORT}}"
local SESSION_ID = "{{SESSION_ID}}"

-- Only run inside Studio
if not RunService:IsStudio() or RunService:IsRunning() then
	return
end

local thisPlaceSessionId = Workspace:GetAttribute("StudioBridgeSessionId")
if thisPlaceSessionId ~= SESSION_ID then
	return
end

local WS_URL = "ws://localhost:" .. PORT .. "/" .. SESSION_ID

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function jsonEncode(tbl)
	return HttpService:JSONEncode(tbl)
end

local function jsonDecode(str)
	local ok, result = pcall(function()
		return HttpService:JSONDecode(str)
	end)
	if ok then
		return result
	end
	return nil
end

local function send(client, msgType, payload)
	local ok, err = pcall(function()
		client:Send(jsonEncode({
			type = msgType,
			sessionId = SESSION_ID,
			payload = payload,
		}))
	end)
	if not ok then
		warn("[StudioBridge] Send failed: " .. tostring(err))
	end
end

-- ---------------------------------------------------------------------------
-- Output batching — collect LogService messages and flush every 0.1s
-- ---------------------------------------------------------------------------

local outputBuffer = {}
local bufferLock = false

local function flushOutput(client)
	if #outputBuffer == 0 or bufferLock then
		return
	end

	bufferLock = true
	local batch = outputBuffer
	outputBuffer = {}
	bufferLock = false

	send(client, "output", { messages = batch })
end

-- Map Roblox MessageType enum to string levels
local LEVEL_MAP = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

-- ---------------------------------------------------------------------------
-- Script execution
-- ---------------------------------------------------------------------------

local function executeScript(client, source)
	local fn, loadErr = loadstring(source)
	if not fn then
		send(client, "scriptComplete", {
			success = false,
			error = "loadstring failed: " .. tostring(loadErr),
		})
		return
	end

	local ok, runErr = xpcall(fn, debug.traceback)

	-- Small delay to let any final prints flush through LogService
	task.wait(0.2)
	flushOutput(client)

	send(client, "scriptComplete", {
		success = ok,
		error = if ok then nil else tostring(runErr),
	})
end

-- ---------------------------------------------------------------------------
-- WebSocket connection
-- ---------------------------------------------------------------------------

local function connectAsync()
	local client

	local ok, err = pcall(function()
		client = HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, { Url = WS_URL })
	end)

	if not ok or not client then
		warn("[StudioBridge] Failed to create WebSocket client: " .. tostring(err))
		return
	end

	-- Hook LogService before connecting so we don't miss early messages.
	-- Filter out internal [StudioBridge] messages so they don't leak back
	-- to the CLI as script output.
	local logConnection = LogService.MessageOut:Connect(function(message, messageType)
		if string.sub(message, 1, 14) == "[StudioBridge]" then
			return
		end

		local level = LEVEL_MAP[messageType] or "Print"
		table.insert(outputBuffer, {
			level = level,
			body = message,
		})
	end)

	-- Periodic flush
	local flushConnection = RunService.Heartbeat:Connect(function()
		if #outputBuffer > 0 then
			flushOutput(client)
		end
	end)

	-- Connection opens automatically on CreateWebStreamClient — send hello
	-- once the Opened event fires.
	client.Opened:Connect(function(_responseStatusCode, _headers)
		print("[StudioBridge] WebSocket opened, sending hello (session: " .. SESSION_ID .. ")")
		send(client, "hello", {
			sessionId = SESSION_ID,
		})
	end)

	-- Handle incoming messages from the server
	client.MessageReceived:Connect(function(rawData)
		local msg = jsonDecode(rawData)
		if not msg or type(msg.type) ~= "string" then
			return
		end

		-- Validate session ID on every incoming message
		if msg.sessionId ~= SESSION_ID then
			warn("[StudioBridge] Ignoring message with wrong session ID")
			return
		end

		if msg.type == "welcome" then
			-- Handshake accepted — ready for execute messages
			print("[StudioBridge] Connected, ready for commands")
		elseif msg.type == "execute" then
			-- Execute an additional script sent by the server
			if msg.payload and type(msg.payload.script) == "string" then
				task.spawn(function()
					executeScript(client, msg.payload.script)
				end)
			end
		elseif msg.type == "shutdown" then
			-- Clean up
			print("[StudioBridge] Shutdown requested")
			logConnection:Disconnect()
			flushConnection:Disconnect()
			pcall(function()
				client:Close()
			end)
		end
	end)

	client.Closed:Connect(function()
		logConnection:Disconnect()
		flushConnection:Disconnect()
	end)

	client.Error:Connect(function(responseStatusCode, errorMessage)
		warn(
			"[StudioBridge] WebSocket error (status " .. tostring(responseStatusCode) .. "): " .. tostring(errorMessage)
		)
	end)
end

-- Run
task.spawn(connectAsync)
