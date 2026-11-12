--!strict
--[=[
	State machine for finding a studio-bridge server and holding the connection
	to it. Moves through `idle`, `searching`, `connecting` and `connected`.

	All I/O goes through the injected callbacks. The caller drives it by calling
	[DiscoveryStateMachine.PollAsync] in a loop, passing how much of the loop's
	time budget is left so scanning never overruns it.

	@class DiscoveryStateMachine
]=]

local DEFAULT_PORT_MIN = 38741
local DEFAULT_PORT_MAX = 38744
local DEFAULT_POLL_INTERVAL_SEC = 2
local DEFAULT_TIME_AVAILABLE_SEC = 10

local DiscoveryStateMachine = {}
DiscoveryStateMachine.ClassName = "DiscoveryStateMachine"
DiscoveryStateMachine.__index = DiscoveryStateMachine

export type DiscoveryState = "idle" | "searching" | "connecting" | "connected"

export type DiscoveryConfig = {
	portRange: { min: number?, max: number? }?,
	pollIntervalSec: number?,
}

export type DiscoveryCallbacks = {
	scanPortsAsync: (ports: { number }, timeoutSec: number) -> (number?, string?),
	connectWebSocket: (url: string) -> (boolean, any?),
	onStateChange: (oldState: DiscoveryState, newState: DiscoveryState) -> (),
	onConnected: (connection: any, port: number) -> (),
	onDisconnected: (reason: string?) -> (),
}

export type DiscoveryStateMachine = typeof(setmetatable(
	{} :: {
		_portMin: number,
		_portMax: number,
		_pollIntervalSec: number,
		_callbacks: DiscoveryCallbacks,
		_state: DiscoveryState,
		_nextPollAt: number,
		_connection: any?,
	},
	{} :: typeof({ __index = DiscoveryStateMachine })
))

--[=[
	Constructs a state machine in the `idle` state. Scans ports 38741-38744 every
	2 seconds unless `config` says otherwise.
]=]
function DiscoveryStateMachine.new(config: DiscoveryConfig?, callbacks: DiscoveryCallbacks): DiscoveryStateMachine
	local self: DiscoveryStateMachine = setmetatable({} :: any, DiscoveryStateMachine)

	local portRange = config and config.portRange
	self._portMin = portRange and portRange.min or DEFAULT_PORT_MIN
	self._portMax = portRange and portRange.max or DEFAULT_PORT_MAX
	self._pollIntervalSec = config and config.pollIntervalSec or DEFAULT_POLL_INTERVAL_SEC

	self._callbacks = assert(callbacks, "No callbacks")
	self._state = "idle"
	self._nextPollAt = 0
	self._connection = nil

	return self
end

--[=[
	Returns the current state.
]=]
function DiscoveryStateMachine.GetState(self: DiscoveryStateMachine): DiscoveryState
	return self._state
end

--[=[
	Starts searching. Does nothing unless idle.
]=]
function DiscoveryStateMachine.Start(self: DiscoveryStateMachine)
	if self._state ~= "idle" then
		return
	end

	self._nextPollAt = 0
	self:_transitionTo("searching")
end

--[=[
	Returns to idle, reporting a `"stopped"` disconnect if a connection was held.
]=]
function DiscoveryStateMachine.Stop(self: DiscoveryStateMachine)
	if self._state == "idle" then
		return
	end

	local wasConnected = self._state == "connected"
	self._connection = nil
	self._nextPollAt = 0
	self:_transitionTo("idle")

	if wasConnected then
		self._callbacks.onDisconnected("stopped")
	end
end

--[=[
	Reports that the held connection dropped, and resumes searching right away.
]=]
function DiscoveryStateMachine.HandleDisconnect(self: DiscoveryStateMachine, reason: string?)
	if self._state ~= "connected" then
		return
	end

	self._connection = nil
	self._nextPollAt = 0
	self._callbacks.onDisconnected(reason)
	self:_transitionTo("searching")
end

--[=[
	Runs one poll cycle, spending at most `remainingExecTimeSec` (default 10) on
	scanning. Returns immediately while idle, connected, or before the next scan
	is due. May yield.
]=]
function DiscoveryStateMachine.PollAsync(self: DiscoveryStateMachine, remainingExecTimeSec: number?)
	if self._state ~= "searching" then
		return
	end

	if os.clock() < self._nextPollAt then
		return
	end

	local timeAvailable = remainingExecTimeSec or DEFAULT_TIME_AVAILABLE_SEC
	if timeAvailable <= 0 then
		return
	end

	self:_scanPortsAsync(timeAvailable)
end

function DiscoveryStateMachine._transitionTo(self: DiscoveryStateMachine, newState: DiscoveryState)
	local oldState: DiscoveryState = self._state
	if oldState == newState then
		return
	end

	self._state = newState
	self._callbacks.onStateChange(oldState, newState)
end

function DiscoveryStateMachine._scanPortsAsync(self: DiscoveryStateMachine, timeoutSec: number)
	-- Every port is probed in parallel and the first to answer wins, so order is irrelevant
	local ports: { number } = {}
	for port = self._portMin, self._portMax do
		table.insert(ports, port)
	end

	local foundPort = self._callbacks.scanPortsAsync(ports, timeoutSec)
	if not foundPort then
		self._nextPollAt = os.clock() + self._pollIntervalSec
		return
	end

	self:_transitionTo("connecting")
	self:_attemptConnect(foundPort)
end

function DiscoveryStateMachine._attemptConnect(self: DiscoveryStateMachine, port: number)
	local success, connection = self._callbacks.connectWebSocket(`ws://localhost:{port}/plugin`)
	if not (success and connection) then
		self._nextPollAt = os.clock() + self._pollIntervalSec
		self:_transitionTo("searching")
		return
	end

	self._connection = connection
	self._nextPollAt = 0
	self:_transitionTo("connected")
	self._callbacks.onConnected(connection, port)
end

return DiscoveryStateMachine
