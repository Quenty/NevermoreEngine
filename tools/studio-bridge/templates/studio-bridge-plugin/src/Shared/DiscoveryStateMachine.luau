--[[
	Pure state machine for plugin discovery and connection lifecycle.

	Manages the states: idle, searching, connecting, connected, reconnecting.
	Uses a tick(deltaMs) pattern for deterministic testing -- no real timers,
	no Roblox APIs. All external I/O is performed via injected callbacks.

	Port scanning iterates through a configurable range, calling httpGet on
	each port's /health endpoint. On success, connectWebSocket is called
	to establish the connection.

	Reconnection uses exponential backoff: initialBackoffMs * 2^attempt,
	capped at maxBackoffMs.
]]

local DiscoveryStateMachine = {}
DiscoveryStateMachine.__index = DiscoveryStateMachine

-- ---------------------------------------------------------------------------
-- Default configuration
-- ---------------------------------------------------------------------------

local DEFAULT_CONFIG = {
	portRange = { min = 38741, max = 38744 },
	defaultPort = 38741,
	pollIntervalMs = 2000,
	maxReconnectAttempts = 10,
	initialBackoffMs = 1000,
	maxBackoffMs = 30000,
	heartbeatIntervalMs = 5000,
}

-- ---------------------------------------------------------------------------
-- Constructor
-- ---------------------------------------------------------------------------

--[[
	Create a new DiscoveryStateMachine.

	@param config Optional configuration overrides.
	@param callbacks Required callback table for external I/O.
]]
function DiscoveryStateMachine.new(
	config: {
		portRange: { min: number, max: number }?,
		pollIntervalMs: number?,
		maxReconnectAttempts: number?,
		initialBackoffMs: number?,
		maxBackoffMs: number?,
		heartbeatIntervalMs: number?,
	}?,
	callbacks: {
		httpGet: (url: string) -> (boolean, string?),
		connectWebSocket: (url: string) -> (boolean, any?),
		onStateChange: (oldState: string, newState: string) -> (),
		onConnected: (connection: any) -> (),
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
		_elapsedMs = 0,
		_pollElapsedMs = 0,
		_reconnectAttempt = 0,
		_backoffElapsedMs = 0,
		_backoffTargetMs = 0,
		_isReconnecting = false, -- tracks whether we are in a reconnect cycle
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
-- Internal: calculate backoff for current attempt
-- ---------------------------------------------------------------------------

function DiscoveryStateMachine._calculateBackoff(self: any): number
	-- Exponential backoff: initialBackoffMs * 2^attempt, capped at maxBackoffMs
	local backoff = self._config.initialBackoffMs * (2 ^ self._reconnectAttempt)
	if backoff > self._config.maxBackoffMs then
		backoff = self._config.maxBackoffMs
	end
	return backoff
end

-- ---------------------------------------------------------------------------
-- Public methods
-- ---------------------------------------------------------------------------

--[[
	Start discovery. Transitions from idle to searching.
]]
function DiscoveryStateMachine.start(self: any)
	if self._state ~= "idle" then
		return
	end
	self._currentPort = self._config.portRange.min
	self._pollElapsedMs = 0
	self._reconnectAttempt = 0
	self._isReconnecting = false
	-- Trigger immediate scan on first tick
	self._pollElapsedMs = self._config.pollIntervalMs
	self:_transitionTo("searching")
end

--[[
	Stop discovery. Transitions to idle from any state, resets internal state.
]]
function DiscoveryStateMachine.stop(self: any)
	if self._state == "idle" then
		return
	end
	local wasConnected = self._state == "connected"
	self._connection = nil
	self._reconnectAttempt = 0
	self._isReconnecting = false
	self._pollElapsedMs = 0
	self._backoffElapsedMs = 0
	self._backoffTargetMs = 0
	self._currentPort = self._config.portRange.min
	self:_transitionTo("idle")
	if wasConnected then
		self._callbacks.onDisconnected("stopped")
	end
end

--[[
	Signal that the current connection was lost.
	Transitions from connected back to searching immediately so the
	plugin can discover a new host without waiting for exponential backoff.
]]
function DiscoveryStateMachine.onDisconnect(self: any, reason: string?)
	if self._state ~= "connected" then
		return
	end
	self._connection = nil
	self._reconnectAttempt = 0
	self._isReconnecting = false
	self._backoffElapsedMs = 0
	self._backoffTargetMs = 0
	-- Trigger immediate scan on next tick
	self._pollElapsedMs = self._config.pollIntervalMs
	self._callbacks.onDisconnected(reason)
	self:_transitionTo("searching")
end

--[[
	Advance the state machine by deltaMs milliseconds.
	This drives all timing deterministically for testing.
]]
function DiscoveryStateMachine.tick(self: any, deltaMs: number)
	if self._state == "idle" or self._state == "connected" then
		return
	end

	if self._state == "searching" then
		self._pollElapsedMs = self._pollElapsedMs + deltaMs
		if self._pollElapsedMs >= self._config.pollIntervalMs then
			self._pollElapsedMs = 0
			self:_scanPorts()
		end
	elseif self._state == "reconnecting" then
		self._backoffElapsedMs = self._backoffElapsedMs + deltaMs
		if self._backoffElapsedMs >= self._backoffTargetMs then
			self._reconnectAttempt = self._reconnectAttempt + 1
			if self._reconnectAttempt >= self._config.maxReconnectAttempts then
				self._isReconnecting = false
				self._reconnectAttempt = 0
				self:_transitionTo("idle")
				return
			end
			-- Transition to searching and try scanning immediately
			self._pollElapsedMs = self._config.pollIntervalMs
			self:_transitionTo("searching")
		end
	end
end

-- ---------------------------------------------------------------------------
-- Internal: port scanning
-- ---------------------------------------------------------------------------

function DiscoveryStateMachine._scanPorts(self: any)
	local portMin = self._config.portRange.min
	local portMax = self._config.portRange.max
	local totalPorts = portMax - portMin + 1

	-- Build list of ports to scan, starting from defaultPort (most likely)
	local ports = {}
	for i = 0, totalPorts - 1 do
		local port = portMin + ((self._currentPort - portMin + i) % totalPorts)
		table.insert(ports, port)
	end

	-- scanPorts callback allows the plugin layer to scan in parallel.
	-- Falls back to sequential httpGet if scanPorts is not provided.
	local foundPort, foundBody
	if self._callbacks.scanPorts then
		foundPort, foundBody = self._callbacks.scanPorts(ports)
	else
		for _, port in ports do
			local url = "http://localhost:" .. tostring(port) .. "/health"
			local success, responseBody = self._callbacks.httpGet(url)
			if success then
				foundPort = port
				foundBody = responseBody
				break
			end
		end
	end

	if foundPort then
		self:_transitionTo("connecting")
		self:_attemptConnect(foundPort, foundBody)
		return
	end

	-- All ports failed this scan cycle.
	-- If we are in a reconnection cycle, go back to reconnecting with increased backoff.
	if self._isReconnecting then
		self._backoffElapsedMs = 0
		self._backoffTargetMs = self:_calculateBackoff()
		self:_transitionTo("reconnecting")
	end
	-- Otherwise stay in searching; will retry on next poll interval.
end

-- ---------------------------------------------------------------------------
-- Internal: WebSocket connection attempt
-- ---------------------------------------------------------------------------

function DiscoveryStateMachine._attemptConnect(self: any, port: number, _healthResponse: string?)
	local wsUrl = "ws://localhost:" .. tostring(port) .. "/plugin"
	local success, connection = self._callbacks.connectWebSocket(wsUrl)

	if success and connection then
		self._connection = connection
		self._reconnectAttempt = 0
		self._isReconnecting = false
		self._backoffElapsedMs = 0
		self._backoffTargetMs = 0
		self:_transitionTo("connected")
		self._callbacks.onConnected(connection, port)
	else
		-- Connection failed, go back to searching
		self._pollElapsedMs = 0
		self:_transitionTo("searching")
	end
end

return DiscoveryStateMachine
