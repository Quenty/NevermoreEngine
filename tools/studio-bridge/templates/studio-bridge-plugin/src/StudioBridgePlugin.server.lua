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
local StudioBridgeLogUtils = require(script.Parent.Shared.StudioBridgeLogUtils)
local StudioBridgeSessionUtils = require(script.Parent.Shared.StudioBridgeSessionUtils)

local PORT = "{{PORT}}"
local SESSION_ID = "{{SESSION_ID}}"
local IS_EPHEMERAL = ("{{EPHEMERAL}}" :: string) == "true"

local LOG_BUFFER_CAPACITY = 1000
local POLL_INTERVAL_SEC = 2

local LOG_LEVELS: { [Enum.MessageType]: string } = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

-- Playtests load a plugin instance into their server and client, but only when
-- Studio's "load user plugins on playtest" setting is on. Those instances cannot
-- make the HTTP requests port discovery needs, so they only connect in a
-- playtest studio-bridge started, which hands them the port and the instance id
-- of the edit session that started it.
local playtestArgs: StudioBridgeSessionUtils.PlaytestArgs? = nil
if RunService:IsRunning() then
	local ok, testArgs = pcall(function()
		return (game:GetService("StudioTestService") :: any):GetTestArgs()
	end)
	playtestArgs = if ok then StudioBridgeSessionUtils.getPlaytestArgs(testArgs) else nil
end
if not RunService:IsStudio() or (RunService:IsRunning() and not playtestArgs) then
	return
end

local function createNonce(): string
	return string.lower(string.sub(HttpService:GenerateGUID(false), 1, 4))
end

local context: StudioBridgeSessionUtils.PluginContext = StudioBridgeSessionUtils.getContext()
local nonceOk, nonce = pcall(StudioBridgeSessionUtils.getOrCreateNonce, game:GetService("CoreGui"), createNonce)
if not nonceOk then
	nonce = createNonce()
end

-- Read on every connect: Studio can load plugins before it names the DataModel after the place
local function getInstanceId(): string
	if playtestArgs then
		return playtestArgs.instanceId
	end
	return StudioBridgeSessionUtils.getInstanceId(game.Name, nonce)
end
local playtestPort = if playtestArgs then playtestArgs.port else nil

local router = ActionRouter.new()
local logBuffer = MessageBuffer.new(LOG_BUFFER_CAPACITY)
local currentConnection: StudioBridgeConnection.StudioBridgeConnection? = nil
local currentWebSocket: any = nil
local discovery: DiscoveryStateMachine.DiscoveryStateMachine? = nil
local pollThread: thread? = nil
local nameConnection: RBXScriptConnection? = nil
local isUnloaded = false

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

local logConnection = LogService.MessageOut:Connect(function(message, messageType)
	if string.sub(message, 1, #StudioBridgeLogUtils.PREFIX) == StudioBridgeLogUtils.PREFIX then
		return
	end

	logBuffer:Push({
		level = LOG_LEVELS[messageType] or "Print",
		body = message,
		timestamp = timeBase + (os.clock() - clockBase),
	})
end)

local function openConnection(webSocket: any, sessionId: string, label: string)
	if isUnloaded then
		return
	end

	if currentConnection then
		currentConnection:Destroy()
	end

	currentConnection = StudioBridgeConnection.new({
		webSocket = webSocket,
		router = router,
		sessionId = sessionId,
		registerPayload = StudioBridgeSessionUtils.createRegisterPayload(getInstanceId(), context),
	})

	StudioBridgeLogUtils.logVerbose(`Connected to {label} as {sessionId}`)
end

local function createWebSocket(url: string): (boolean, any)
	local ok, webSocket = pcall(function()
		return HttpService:CreateWebStreamClient(Enum.WebStreamClientType.WebSocket, { Url = url })
	end)
	if ok then
		currentWebSocket = webSocket
	end
	return ok, webSocket
end

-- Reloading the plugin destroys this script, but the socket callbacks and the
-- poll loop outlive it, leaving the old instance connected beside the new one
plugin.Unloading:Connect(function()
	isUnloaded = true
	logConnection:Disconnect()
	if nameConnection then
		nameConnection:Disconnect()
		nameConnection = nil
	end

	if pollThread then
		task.cancel(pollThread)
		pollThread = nil
	end
	if discovery then
		discovery:Stop()
	end
	if currentConnection then
		currentConnection:Destroy()
		currentConnection = nil
	end
	if currentWebSocket then
		pcall(function()
			currentWebSocket:Close()
		end)
		currentWebSocket = nil
	end

	router:Destroy()
end)

local function warnOnError(webSocket: any)
	webSocket.Error:Connect(function(status, err)
		StudioBridgeLogUtils.logVerbose(`WebSocket error ({status}): {err}`)
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
		StudioBridgeLogUtils.warn("Failed to create WebSocket client")
		return
	end

	webSocket.Opened:Connect(function()
		openConnection(webSocket, SESSION_ID, `localhost:{PORT} (ephemeral)`)
	end)
	warnOnError(webSocket)
	return
end

local stateMachine: DiscoveryStateMachine.DiscoveryStateMachine
stateMachine = DiscoveryStateMachine.new(nil, {
	scanPortsAsync = if playtestPort
		then function()
			return playtestPort, nil
		end
		else scanPortsAsync,
	connectWebSocket = createWebSocket,
	onStateChange = function(oldState, newState)
		if oldState == "idle" and newState == "searching" then
			StudioBridgeLogUtils.logVerbose("Searching for host on ports 38741-38744...")
		end
	end,
	onConnected = function(webSocket, port)
		webSocket.Opened:Connect(function()
			openConnection(
				webSocket,
				StudioBridgeSessionUtils.getSessionId(getInstanceId(), context),
				`localhost:{port}`
			)
		end)
		webSocket.Closed:Connect(function()
			stateMachine:HandleDisconnect("closed")
		end)
		warnOnError(webSocket)
	end,
	onDisconnected = function(reason)
		StudioBridgeLogUtils.logVerbose(`Disconnected ({reason}), searching...`)
	end,
})

discovery = stateMachine

stateMachine:Start()

-- Reconnecting re-registers under the session id for the new name
nameConnection = game:GetPropertyChangedSignal("Name"):Connect(function()
	if currentWebSocket then
		pcall(function()
			currentWebSocket:Close()
		end)
	end
end)

-- Each cycle gets a fixed time budget, which PollAsync threads through to the port scan
pollThread = task.spawn(function()
	while true do
		local startTime = os.clock()
		stateMachine:PollAsync(POLL_INTERVAL_SEC)

		local remaining = POLL_INTERVAL_SEC - (os.clock() - startTime)
		if remaining > 0 then
			task.wait(remaining)
		else
			task.wait()
		end
	end
end)
