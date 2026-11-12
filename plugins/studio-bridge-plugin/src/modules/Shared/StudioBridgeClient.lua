--!strict
--[=[
	The studio-bridge client: an action router, the log buffer `queryLogs` reads,
	and the WebSocket to the bridge.

	It connects one of three ways:

	- Ephemeral: `ephemeral` names the port and session id the CLI built the
	  plugin for.
	- Playtest: `playtestArgs` names the bridge port, handed over through the
	  StudioTestService test args, since a playtest cannot make the HTTP requests
	  port discovery needs.
	- Persistent: scans for a running bridge with DiscoveryStateMachine and
	  reconnects whenever it drops.

	@class StudioBridgeClient
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")

local ActionRouter = require("ActionRouter")
local BuiltInActions = require("BuiltInActions")
local DiscoveryStateMachine = require("DiscoveryStateMachine")
local MessageBuffer = require("MessageBuffer")
local StudioBridgeConnection = require("StudioBridgeConnection")
local StudioBridgeLogUtils = require("StudioBridgeLogUtils")
local StudioBridgeSessionUtils = require("StudioBridgeSessionUtils")

local LOG_BUFFER_CAPACITY = 1000
local POLL_INTERVAL_SEC = 2

local LOG_LEVELS: { [Enum.MessageType]: string } = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

local StudioBridgeClient = {}

export type Options = {
	ephemeral: { port: string, sessionId: string }?,
	playtestArgs: StudioBridgeSessionUtils.PlaytestArgs?,
	compile: ActionRouter.Compiler?,
	vendorPng: any?,
	playtestBridgeTemplate: Instance?,
	pushedModules: Instance?,
}

--[=[
	Starts the client and returns a function that stops it. Socket callbacks and
	the poll loop outlive the script that started them, so the owner must stop it
	when it unloads.
]=]
function StudioBridgeClient.start(options: Options): () -> ()
	local playtestArgs = options.playtestArgs

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

	local function getPlayerName(): string?
		local player = if context == "client" then Players.LocalPlayer else nil
		return if player then player.Name else nil
	end

	-- The clients of a multiplayer test share an instance id, so their session ids name their player
	local function getSessionId(): string
		local isMultiplayerClient = playtestArgs and playtestArgs.multiplayer and context == "client"
		return StudioBridgeSessionUtils.getSessionId(
			getInstanceId(),
			context,
			if isMultiplayerClient then getPlayerName() else nil
		)
	end

	local router = ActionRouter.new()
	local logBuffer = MessageBuffer.new(LOG_BUFFER_CAPACITY)
	local currentConnection: StudioBridgeConnection.StudioBridgeConnection? = nil
	local currentWebSocket: any = nil
	local discovery: DiscoveryStateMachine.DiscoveryStateMachine? = nil
	local pollThread: thread? = nil
	local nameConnection: RBXScriptConnection? = nil
	local isStopped = false

	if options.vendorPng then
		router:SetVendorPng(options.vendorPng)
	end
	if options.compile then
		router:SetCompiler(options.compile)
	end
	if options.playtestBridgeTemplate then
		router:SetPlaytestBridgeTemplate(options.playtestBridgeTemplate)
	end
	if options.pushedModules then
		router:SetModuleFolder(options.pushedModules)
	end

	BuiltInActions.register(router, function(message)
		if currentConnection then
			currentConnection:Send(message)
		end
	end, logBuffer)

	-- Hybrid clock: the wall clock at load, then os.clock() deltas, which are cheaper per entry
	local clockBase = os.clock()
	local timeBase = DateTime.now().UnixTimestampMillis / 1000

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
		if isStopped then
			return
		end

		if currentConnection then
			currentConnection:Destroy()
		end

		currentConnection = StudioBridgeConnection.new({
			webSocket = webSocket,
			router = router,
			sessionId = sessionId,
			registerPayload = StudioBridgeSessionUtils.createRegisterPayload(
				getInstanceId(),
				context,
				StudioBridgeSessionUtils.getLaunchId(workspace),
				getPlayerName(),
				if playtestArgs then playtestArgs.playtestId else nil
			),
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

	local function stop()
		if isStopped then
			return
		end
		isStopped = true
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
	end

	local function warnOnError(webSocket: any)
		webSocket.Error:Connect(function(status, err)
			StudioBridgeLogUtils.logVerbose(`WebSocket error ({status}): {err}`)
		end)
	end

	local ephemeral = options.ephemeral
	if ephemeral then
		-- Every open Studio loads this plugin, but only the one launched for this run
		-- has the session id stamped on its place, which may load after the plugin
		local function connectEphemeral()
			if StudioBridgeSessionUtils.getLaunchId(workspace) ~= ephemeral.sessionId or currentWebSocket then
				return
			end

			local ok, webSocket = createWebSocket(`ws://localhost:{ephemeral.port}/{ephemeral.sessionId}`)
			if not (ok and webSocket) then
				StudioBridgeLogUtils.warn("Failed to create WebSocket client")
				return
			end

			webSocket.Opened:Connect(function()
				openConnection(webSocket, ephemeral.sessionId, `localhost:{ephemeral.port} (ephemeral)`)
			end)
			warnOnError(webSocket)
		end

		nameConnection = workspace:GetAttributeChangedSignal("StudioBridgeSessionId"):Connect(connectEphemeral)
		connectEphemeral()
		return stop
	end

	-- A multiplayer client's session id names its player, so wait for one
	if playtestArgs and playtestArgs.multiplayer and context == "client" then
		while not Players.LocalPlayer do
			Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		end
	end

	local playtestPort = if playtestArgs then playtestArgs.port else nil

	local stateMachine: DiscoveryStateMachine.DiscoveryStateMachine
	stateMachine = DiscoveryStateMachine.new(nil, {
		scanPortsAsync = if playtestPort
			then function()
				return playtestPort, nil
			end
			else function(ports: { number }, timeoutSec: number)
				return StudioBridgeClient._scanPortsAsync(ports, timeoutSec)
			end,
		connectWebSocket = createWebSocket,
		onStateChange = function(oldState, newState)
			if oldState == "idle" and newState == "searching" then
				StudioBridgeLogUtils.logVerbose("Searching for host on ports 38741-38744...")
			end
		end,
		onConnected = function(webSocket, port)
			webSocket.Opened:Connect(function()
				openConnection(webSocket, getSessionId(), `localhost:{port}`)
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

	-- Reconnecting re-registers under the session id for the new name. A
	-- playtest's id comes from its test args, so a rename leaves it unchanged.
	if not playtestArgs then
		nameConnection = game:GetPropertyChangedSignal("Name"):Connect(function()
			if currentWebSocket then
				pcall(function()
					currentWebSocket:Close()
				end)
			end
		end)
	end

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

	return stop
end

--[[
	Probes every port's /health endpoint in parallel and returns the first port
	to answer, or nil once all fail or the timeout passes. The caller is resumed
	with task.defer so it has reached coroutine.yield() first.
]]
function StudioBridgeClient._scanPortsAsync(ports: { number }, timeoutSec: number): (number?, string?)
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

return StudioBridgeClient
