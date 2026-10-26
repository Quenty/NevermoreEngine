--!strict
--[[
	Entry point for the studio-bridge plugin. Wires the modules under Shared/ to
	Roblox services and boots in one of two modes:

	- Ephemeral: the CLI substituted the build constants below, so it connects
	  straight to that port and session.
	- Persistent: the constants are left empty, so it scans for a
	  running bridge with DiscoveryStateMachine and reconnects whenever it drops.

	The plugin cannot use the Nevermore loader: rojo builds this template on its
	own from the published CLI package, without any node_modules.
]]

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")

local ActionRouter = require(script.Parent.Shared.ActionRouter)
local BuiltInActions = require(script.Parent.Shared.BuiltInActions)
local DiscoveryStateMachine = require(script.Parent.Shared.DiscoveryStateMachine)
local MessageBuffer = require(script.Parent.Shared.MessageBuffer)
local StudioBridgeConnection = require(script.Parent.Shared.StudioBridgeConnection)
local StudioBridgeSessionUtils = require(script.Parent.Shared.StudioBridgeSessionUtils)

local PORT = "{{PORT}}"
local SESSION_ID = "{{SESSION_ID}}"
local IS_EPHEMERAL = ("{{EPHEMERAL}}" :: string) == "true"

local LOG_PREFIX = "[StudioBridge]"
local LOG_BUFFER_CAPACITY = 1000
local POLL_INTERVAL_SEC = 2

local LOG_LEVELS: { [Enum.MessageType]: string } = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

-- Play mode spawns extra plugin instances for the client and server, which
-- cannot make HTTP requests. The edit instance stays alive through play mode.
if not RunService:IsStudio() or RunService:IsRunning() then
	return
end

-- Generated once per plugin lifetime, so the session id survives reconnects
local nonce = string.sub(HttpService:GenerateGUID(false), 1, 8)
local context: StudioBridgeSessionUtils.PluginContext = StudioBridgeSessionUtils.getContext()
local instanceId = StudioBridgeSessionUtils.getInstanceId(game.GameId, game.PlaceId, game.Name, nonce)

local router = ActionRouter.new()
local logBuffer = MessageBuffer.new(LOG_BUFFER_CAPACITY)
local currentConnection: StudioBridgeConnection.StudioBridgeConnection? = nil

local pngOk, png = pcall(function()
	return (require :: any)(script.Parent.Vendor.png)
end)
if pngOk then
	router:SetVendorPng(png)
end

BuiltInActions.register(router, function(message)
	if currentConnection then
		currentConnection:Send(message)
	end
end, logBuffer)

-- Hybrid clock: os.time() for the wall clock, os.clock() deltas for sub-second precision
local clockBase = os.clock()
local timeBase = os.time()

LogService.MessageOut:Connect(function(message, messageType)
	if string.sub(message, 1, #LOG_PREFIX) == LOG_PREFIX then
		return
	end

	logBuffer:Push({
		level = LOG_LEVELS[messageType] or "Print",
		body = message,
		timestamp = timeBase + (os.clock() - clockBase),
	})
end)

local function openConnection(webSocket: any, sessionId: string, label: string)
	if currentConnection then
		currentConnection:Destroy()
	end

	currentConnection = StudioBridgeConnection.new({
		webSocket = webSocket,
		router = router,
		sessionId = sessionId,
		registerPayload = StudioBridgeSessionUtils.createRegisterPayload(instanceId, context),
	})

	print(`{LOG_PREFIX} Connected to {label} as {sessionId}`)
end

local function createWebSocket(url: string): (boolean, any)
	return pcall(function()
		return HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, { Url = url })
	end)
end

local function warnOnError(webSocket: any)
	webSocket.Error:Connect(function(status, err)
		warn(`{LOG_PREFIX} WebSocket error ({status}): {err}`)
	end)
end

--[[
	Probes every port's /health endpoint in parallel and returns the first port
	to answer, or nil once all fail or the timeout passes. The caller is resumed
	with task.defer so it has reached coroutine.yield() first.
]]
local function scanPortsAsync(ports: { number }, timeoutSec: number): (number?, string?)
	local callerThread = coroutine.running()
	local foundPort: number? = nil
	local foundBody: string? = nil
	local remaining = #ports
	local settled = false

	local function settle()
		if not settled then
			settled = true
			task.defer(callerThread)
		end
	end

	local threads: { thread } = {}
	for _, port in ports do
		table.insert(
			threads,
			task.spawn(function()
				local ok, body = pcall(HttpService.GetAsync, HttpService, `http://localhost:{port}/health`)
				if ok and not settled then
					foundPort = port
					foundBody = body
					settle()
					return
				end

				remaining -= 1
				if remaining <= 0 then
					settle()
				end
			end)
		)
	end
	table.insert(threads, task.delay(timeoutSec, settle))

	coroutine.yield()

	for _, thread in threads do
		pcall(task.cancel, thread)
	end

	return foundPort, foundBody
end

if IS_EPHEMERAL then
	local ok, webSocket = createWebSocket(`ws://localhost:{PORT}/{SESSION_ID}`)
	if not (ok and webSocket) then
		warn(`{LOG_PREFIX} Failed to create WebSocket client`)
		return
	end

	webSocket.Opened:Connect(function()
		openConnection(webSocket, SESSION_ID, `localhost:{PORT} (ephemeral)`)
	end)
	warnOnError(webSocket)
	return
end

local sessionId = StudioBridgeSessionUtils.getSessionId(instanceId, context)

local discovery: DiscoveryStateMachine.DiscoveryStateMachine
discovery = DiscoveryStateMachine.new(nil, {
	scanPortsAsync = scanPortsAsync,
	connectWebSocket = createWebSocket,
	onStateChange = function(oldState, newState)
		if oldState == "idle" and newState == "searching" then
			print(`{LOG_PREFIX} Searching for host on ports 38741-38744...`)
		end
	end,
	onConnected = function(webSocket, port)
		webSocket.Opened:Connect(function()
			openConnection(webSocket, sessionId, `localhost:{port}`)
		end)
		webSocket.Closed:Connect(function()
			discovery:HandleDisconnect("closed")
		end)
		warnOnError(webSocket)
	end,
	onDisconnected = function(reason)
		print(`{LOG_PREFIX} Disconnected ({reason}), searching...`)
	end,
})

print(`{LOG_PREFIX} Session ID: {sessionId}`)
discovery:Start()

-- Each cycle gets a fixed time budget, which PollAsync threads through to the port scan
task.spawn(function()
	while true do
		local startTime = os.clock()
		discovery:PollAsync(POLL_INTERVAL_SEC)

		local remaining = POLL_INTERVAL_SEC - (os.clock() - startTime)
		if remaining > 0 then
			task.wait(remaining)
		else
			task.wait()
		end
	end
end)
