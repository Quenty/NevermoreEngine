--[[
	Pure state machine for plugin discovery and connection lifecycle.

	Manages the states: idle, searching, connecting, connected.
	All external I/O is performed via injected callbacks.

	The caller drives the loop by calling pollAsync(remainingExecTimeSec)
	repeatedly. The remaining execution time threads through all async
	operations so the entire poll cycle completes within a predictable
	time budget.
]]

local DiscoveryStateMachine = {}
DiscoveryStateMachine.__index = DiscoveryStateMachine

-- ---------------------------------------------------------------------------
-- Default configuration
-- ---------------------------------------------------------------------------

local DEFAULT_CONFIG = {
	portRange = { min = 38741, max = 38744 },
	defaultPort = 38741,
	pollIntervalSec = 2,
}

-- ---------------------------------------------------------------------------
-- Constructor
-- ---------------------------------------------------------------------------

function DiscoveryStateMachine.new(
	config: {
		portRange: { min: number, max: number }?,
		pollIntervalSec: number?,
	}?,
	callbacks: {
		scanPortsAsync: (ports: { number }, timeoutSec: number) -> (number?, string?),
		connectWebSocket: (url: string) -> (boolean, any?),
		onStateChange: (oldState: string, newState: string) -> (),
		onConnected: (connection: any, port: number) -> (),
		onDisconnected: (reason: string?) -> (),
	}
)
	local resolvedConfig = {}
	local userConfig = config or {}
	for key, default in DEFAULT_CONFIG do
		if key == "portRange" then
			local userRange = (userConfig :: any).portRange
			if userRange then
				resolvedConfig.portRange = {
					min = userRange.min or default.min,
					max = userRange.max or default.max,
				}
			else
				resolvedConfig.portRange = { min = default.min, max = default.max }
			end
		else
			resolvedConfig[key] = (userConfig :: any)[key] or default
		end
	end

	local self = setmetatable({
		_config = resolvedConfig,
		_callbacks = callbacks,
		_state = "idle" :: string,
		_currentPort = resolvedConfig.defaultPort or resolvedConfig.portRange.min,
		_nextPollAt = 0, -- os.clock() time for next scan
		_connection = nil :: any?,
	}, DiscoveryStateMachine)

	return self
end

-- ---------------------------------------------------------------------------
-- State accessors
-- ---------------------------------------------------------------------------

function DiscoveryStateMachine.getState(self: any): string
	return self._state
end

-- ---------------------------------------------------------------------------
-- Internal state transition
-- ---------------------------------------------------------------------------

function DiscoveryStateMachine._transitionTo(self: any, newState: string)
	local oldState = self._state
	if oldState == newState then
		return
	end
	self._state = newState
	self._callbacks.onStateChange(oldState, newState)
end

-- ---------------------------------------------------------------------------
-- Public methods
-- ---------------------------------------------------------------------------

function DiscoveryStateMachine.start(self: any)
	if self._state ~= "idle" then
		return
	end
	self._currentPort = self._config.portRange.min
	self._nextPollAt = 0
	self:_transitionTo("searching")
end

function DiscoveryStateMachine.stop(self: any)
	if self._state == "idle" then
		return
	end
	local wasConnected = self._state == "connected"
	self._connection = nil
	self._nextPollAt = 0
	self._currentPort = self._config.portRange.min
	self:_transitionTo("idle")
	if wasConnected then
		self._callbacks.onDisconnected("stopped")
	end
end

function DiscoveryStateMachine.onDisconnect(self: any, reason: string?)
	if self._state ~= "connected" then
		return
	end
	self._connection = nil
	self._nextPollAt = 0
	self._callbacks.onDisconnected(reason)
	self:_transitionTo("searching")
end

--[[
	Run one poll cycle. remainingExecTimeSec is the number of seconds this
	call is allowed to spend on async work (port scanning, connecting).
	The caller subtracts elapsed time before each call so the entire loop
	iteration stays within its time budget.

	Returns immediately if not time to scan yet, or if in idle/connected state.
	May yield during port scanning and WebSocket connection.
]]
function DiscoveryStateMachine.pollAsync(self: any, remainingExecTimeSec: number?)
	if self._state == "idle" or self._state == "connected" then
		return
	end

	local now = os.clock()
	local timeAvailable = remainingExecTimeSec or 10

	if self._state == "searching" then
		if now < self._nextPollAt then
			return
		end
		if timeAvailable <= 0 then
			return
		end
		self:_scanPortsAsync(timeAvailable)
	end
end

-- ---------------------------------------------------------------------------
-- Internal: port scanning
-- ---------------------------------------------------------------------------

function DiscoveryStateMachine._scanPortsAsync(self: any, timeoutSec: number)
	local portMin = self._config.portRange.min
	local portMax = self._config.portRange.max
	local totalPorts = portMax - portMin + 1

	local ports = {}
	for i = 0, totalPorts - 1 do
		local port = portMin + ((self._currentPort - portMin + i) % totalPorts)
		table.insert(ports, port)
	end

	local foundPort, foundBody = self._callbacks.scanPortsAsync(ports, timeoutSec)

	if foundPort then
		self:_transitionTo("connecting")
		self:_attemptConnect(foundPort, foundBody)
		return
	end

	-- All ports failed. Schedule next scan at the regular poll interval.
	self._nextPollAt = os.clock() + self._config.pollIntervalSec
end

-- ---------------------------------------------------------------------------
-- Internal: WebSocket connection attempt
-- ---------------------------------------------------------------------------

function DiscoveryStateMachine._attemptConnect(self: any, port: number, _healthResponse: string?)
	local wsUrl = "ws://localhost:" .. tostring(port) .. "/plugin"
	local success, connection = self._callbacks.connectWebSocket(wsUrl)

	if success and connection then
		self._connection = connection
		self._nextPollAt = 0
		self:_transitionTo("connected")
		self._callbacks.onConnected(connection, port)
	else
		self._nextPollAt = os.clock() + self._config.pollIntervalSec
		self:_transitionTo("searching")
	end
end

return DiscoveryStateMachine
