--[[
	Tests for DiscoveryStateMachine.

	Covers all state transitions, tick-based timing, port scanning,
	exponential backoff, and callback invocations using mock callbacks.
]]

local DiscoveryStateMachine = require("../../studio-bridge-plugin/src/Shared/DiscoveryStateMachine")

-- ---------------------------------------------------------------------------
-- Test helpers
-- ---------------------------------------------------------------------------

local function assertEqual(actual: any, expected: any, label: string?)
	if actual ~= expected then
		error(
			string.format(
				"%sexpected %s, got %s",
				if label then label .. ": " else "",
				tostring(expected),
				tostring(actual)
			)
		)
	end
end

local function assertTrue(value: any, label: string?)
	if not value then
		error(
			string.format(
				"%sexpected truthy value, got %s",
				if label then label .. ": " else "",
				tostring(value)
			)
		)
	end
end

local function assertLessThanOrEqual(actual: number, expected: number, label: string?)
	if actual > expected then
		error(
			string.format(
				"%sexpected <= %s, got %s",
				if label then label .. ": " else "",
				tostring(expected),
				tostring(actual)
			)
		)
	end
end

-- ---------------------------------------------------------------------------
-- Mock callback factory
-- ---------------------------------------------------------------------------

local function createMockCallbacks()
	local mock = {
		stateChanges = {} :: { { old: string, new: string } },
		connectedCalls = {} :: { any },
		disconnectedCalls = {} :: { string? },
		httpGetCalls = {} :: { string },
		connectWebSocketCalls = {} :: { string },
		httpGetResult = { success = false, body = nil :: string? },
		wsResult = { success = false, connection = nil :: any? },
		httpGetPortResults = {} :: { [number]: { success: boolean, body: string? } },
	}

	mock.httpGet = function(url: string): (boolean, string?)
		table.insert(mock.httpGetCalls, url)
		local port = tonumber(string.match(url, ":(%d+)/"))
		if port and mock.httpGetPortResults[port] then
			local result = mock.httpGetPortResults[port]
			return result.success, result.body
		end
		return mock.httpGetResult.success, mock.httpGetResult.body
	end

	mock.connectWebSocket = function(url: string): (boolean, any?)
		table.insert(mock.connectWebSocketCalls, url)
		return mock.wsResult.success, mock.wsResult.connection
	end

	mock.onStateChange = function(oldState: string, newState: string)
		table.insert(mock.stateChanges, { old = oldState, new = newState })
	end

	mock.onConnected = function(connection: any)
		table.insert(mock.connectedCalls, connection)
	end

	mock.onDisconnected = function(reason: string?)
		table.insert(mock.disconnectedCalls, reason)
	end

	return mock
end

-- Small config for fast tests
local TEST_CONFIG = {
	portRange = { min = 38740, max = 38745 },
	pollIntervalMs = 2000,
	maxReconnectAttempts = 3,
	initialBackoffMs = 1000,
	maxBackoffMs = 8000,
	heartbeatIntervalMs = 5000,
}

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

local tests = {}

-- 1. State starts as idle
table.insert(tests, {
	name = "state starts as idle",
	fn = function()
		local mock = createMockCallbacks()
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		assertEqual(sm:getState(), "idle")
	end,
})

-- 2. start() transitions to searching
table.insert(tests, {
	name = "start() transitions from idle to searching",
	fn = function()
		local mock = createMockCallbacks()
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		assertEqual(sm:getState(), "searching")
		assertEqual(#mock.stateChanges, 1)
		assertEqual(mock.stateChanges[1].old, "idle")
		assertEqual(mock.stateChanges[1].new, "searching")
	end,
})

-- 3. httpGet success on a port triggers connecting
table.insert(tests, {
	name = "httpGet success triggers transition to connecting",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = false, connection = nil }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:tick(2000)
		-- Should have gone: idle->searching, searching->connecting, connecting->searching (ws failed)
		local foundConnecting = false
		for _, change in mock.stateChanges do
			if change.old == "searching" and change.new == "connecting" then
				foundConnecting = true
				break
			end
		end
		assertTrue(foundConnecting, "should have transitioned to connecting")
	end,
})

-- 4. connectWebSocket success triggers connected + onConnected callback
table.insert(tests, {
	name = "connectWebSocket success triggers connected and onConnected callback",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		local fakeConnection = { id = "conn-42" }
		mock.wsResult = { success = true, connection = fakeConnection }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:tick(2000)
		assertEqual(sm:getState(), "connected")
		assertEqual(#mock.connectedCalls, 1)
		assertEqual(mock.connectedCalls[1].id, "conn-42")
		-- Verify state change sequence
		assertEqual(mock.stateChanges[1].new, "searching")
		assertEqual(mock.stateChanges[2].new, "connecting")
		assertEqual(mock.stateChanges[3].new, "connected")
	end,
})

-- 5. onDisconnect() while connected transitions to reconnecting
table.insert(tests, {
	name = "onDisconnect() while connected transitions to reconnecting",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:tick(2000)
		assertEqual(sm:getState(), "connected")

		sm:onDisconnect("server closed")
		assertEqual(sm:getState(), "reconnecting")
		assertEqual(#mock.disconnectedCalls, 1)
		assertEqual(mock.disconnectedCalls[1], "server closed")
	end,
})

-- 6. After enough tick() calls with failing reconnection, exhausts attempts -> idle
table.insert(tests, {
	name = "exhausting maxReconnectAttempts transitions to idle",
	fn = function()
		local config = {
			portRange = { min = 38740, max = 38742 },
			pollIntervalMs = 100,
			maxReconnectAttempts = 3,
			initialBackoffMs = 100,
			maxBackoffMs = 8000,
			heartbeatIntervalMs = 5000,
		}
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:tick(100)
		assertEqual(sm:getState(), "connected", "initial connection")

		-- Now make everything fail for reconnection
		mock.httpGetResult = { success = false, body = nil }
		mock.wsResult = { success = false, connection = nil }

		sm:onDisconnect("lost")
		assertEqual(sm:getState(), "reconnecting", "entered reconnecting")

		-- The reconnecting cycle: backoff expires -> attempt++, go to searching
		-- -> all ports fail -> back to reconnecting (with increased backoff)
		-- -> repeat until attempts >= maxReconnectAttempts -> idle

		-- Attempt 1: backoff = 100ms (initialBackoffMs * 2^0)
		sm:tick(100)
		assertEqual(sm:getState(), "searching", "searching after 1st backoff")
		-- All ports fail, goes back to reconnecting
		sm:tick(100) -- poll interval fires, all ports fail
		assertEqual(sm:getState(), "reconnecting", "back to reconnecting after scan fail")

		-- Attempt 2: backoff = 200ms (initialBackoffMs * 2^1)
		sm:tick(200)
		assertEqual(sm:getState(), "searching", "searching after 2nd backoff")
		sm:tick(100) -- poll fires, all ports fail
		assertEqual(sm:getState(), "reconnecting", "back to reconnecting again")

		-- Attempt 3: this exhausts maxReconnectAttempts (3)
		sm:tick(400) -- backoff = 400ms (initialBackoffMs * 2^2)
		assertEqual(sm:getState(), "idle", "idle after exhausting attempts")
	end,
})

-- 7. stop() from any state transitions to idle
table.insert(tests, {
	name = "stop() from any state transitions to idle",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }

		-- stop from searching
		local sm1 = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm1:start()
		assertEqual(sm1:getState(), "searching")
		sm1:stop()
		assertEqual(sm1:getState(), "idle", "stop from searching")

		-- stop from connected
		local sm2 = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm2:start()
		sm2:tick(2000)
		assertEqual(sm2:getState(), "connected")
		sm2:stop()
		assertEqual(sm2:getState(), "idle", "stop from connected")

		-- stop from reconnecting
		local sm3 = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm3:start()
		sm3:tick(2000)
		assertEqual(sm3:getState(), "connected")
		mock.httpGetResult = { success = false, body = nil }
		sm3:onDisconnect("lost")
		assertEqual(sm3:getState(), "reconnecting")
		sm3:stop()
		assertEqual(sm3:getState(), "idle", "stop from reconnecting")
	end,
})

-- 8. Backoff doubles each attempt, capped at maxBackoffMs
table.insert(tests, {
	name = "backoff doubles each attempt, capped at maxBackoffMs",
	fn = function()
		local config = {
			portRange = { min = 38740, max = 38741 },
			pollIntervalMs = 10,
			maxReconnectAttempts = 10,
			initialBackoffMs = 100,
			maxBackoffMs = 500,
			heartbeatIntervalMs = 5000,
		}
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:tick(10)
		assertEqual(sm:getState(), "connected")

		mock.httpGetResult = { success = false, body = nil }
		sm:onDisconnect("lost")

		-- Track how long each backoff takes by ticking 1ms at a time
		local backoffs = {}
		for i = 1, 5 do
			assertEqual(sm:getState(), "reconnecting", "reconnecting before backoff " .. tostring(i))
			local ticksNeeded = 0
			while sm:getState() == "reconnecting" do
				sm:tick(1)
				ticksNeeded = ticksNeeded + 1
				if ticksNeeded > 1000 then
					error("infinite loop in backoff " .. tostring(i))
				end
			end
			table.insert(backoffs, ticksNeeded)
			-- Now in searching, tick to trigger scan (all ports fail -> back to reconnecting)
			if sm:getState() == "searching" then
				sm:tick(10)
			end
		end

		-- Expected: 100, 200, 400, 500 (capped), 500 (capped)
		assertEqual(backoffs[1], 100, "1st backoff")
		assertEqual(backoffs[2], 200, "2nd backoff")
		assertEqual(backoffs[3], 400, "3rd backoff")
		assertLessThanOrEqual(backoffs[4], 500, "4th backoff capped")
		assertLessThanOrEqual(backoffs[5], 500, "5th backoff capped")
	end,
})

-- 9. Port scanning wraps around the port range
table.insert(tests, {
	name = "port scanning wraps around the port range",
	fn = function()
		local config = {
			portRange = { min = 38740, max = 38742 },
			pollIntervalMs = 100,
			maxReconnectAttempts = 10,
			initialBackoffMs = 1000,
			maxBackoffMs = 30000,
			heartbeatIntervalMs = 5000,
		}
		local mock = createMockCallbacks()
		-- Only port 38742 responds
		mock.httpGetPortResults[38742] = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:tick(100) -- first scan: tries 38740, 38741, 38742 (success)
		assertEqual(sm:getState(), "connected")

		-- Verify that ports 38740 and 38741 were tried first
		local urls = mock.httpGetCalls
		assertTrue(#urls >= 3, "should have tried at least 3 ports")
		assertTrue(string.find(urls[1], "38740") ~= nil, "first tried 38740")
		assertTrue(string.find(urls[2], "38741") ~= nil, "then tried 38741")
		assertTrue(string.find(urls[3], "38742") ~= nil, "then tried 38742")
	end,
})

-- 10. State change callback fires on each transition
table.insert(tests, {
	name = "state change callback fires on each transition",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)

		sm:start() -- idle -> searching
		sm:tick(2000) -- searching -> connecting -> connected

		sm:onDisconnect("lost") -- connected -> reconnecting

		assertEqual(#mock.stateChanges, 4)
		assertEqual(mock.stateChanges[1].old, "idle")
		assertEqual(mock.stateChanges[1].new, "searching")
		assertEqual(mock.stateChanges[2].old, "searching")
		assertEqual(mock.stateChanges[2].new, "connecting")
		assertEqual(mock.stateChanges[3].old, "connecting")
		assertEqual(mock.stateChanges[3].new, "connected")
		assertEqual(mock.stateChanges[4].old, "connected")
		assertEqual(mock.stateChanges[4].new, "reconnecting")
	end,
})

-- 11. Multiple failed ports before finding one
table.insert(tests, {
	name = "multiple failed ports before finding one that responds",
	fn = function()
		local config = {
			portRange = { min = 38740, max = 38745 },
			pollIntervalMs = 100,
			maxReconnectAttempts = 10,
			initialBackoffMs = 1000,
			maxBackoffMs = 30000,
			heartbeatIntervalMs = 5000,
		}
		local mock = createMockCallbacks()
		-- Only port 38744 responds
		mock.httpGetPortResults[38744] = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:tick(100)
		assertEqual(sm:getState(), "connected")

		-- Should have tried ports 38740-38743 (fail) then 38744 (success)
		local failedPorts = {}
		for i, url in mock.httpGetCalls do
			local port = tonumber(string.match(url, ":(%d+)/"))
			if port and port ~= 38744 then
				table.insert(failedPorts, port)
			end
		end
		-- At least 4 failed ports before the successful one
		assertTrue(#failedPorts >= 4, "should have tried at least 4 failed ports")
	end,
})

-- 12. Immediate searching after idle -> start
table.insert(tests, {
	name = "immediate port scan after start (no delay for first scan)",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		-- Even with pollIntervalMs=2000, the first scan should fire immediately
		-- because start() primes the elapsed time
		sm:tick(1) -- Just 1ms should be enough to trigger the scan
		assertEqual(sm:getState(), "connected", "should connect on first tick after start")
	end,
})

-- 13. tick() is a no-op in idle state
table.insert(tests, {
	name = "tick() is a no-op in idle state",
	fn = function()
		local mock = createMockCallbacks()
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:tick(10000)
		assertEqual(sm:getState(), "idle")
		assertEqual(#mock.httpGetCalls, 0)
		assertEqual(#mock.stateChanges, 0)
	end,
})

-- 14. tick() is a no-op in connected state
table.insert(tests, {
	name = "tick() is a no-op in connected state",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:tick(2000)
		assertEqual(sm:getState(), "connected")

		local callsBefore = #mock.httpGetCalls
		sm:tick(10000) -- large tick in connected state
		assertEqual(sm:getState(), "connected")
		assertEqual(#mock.httpGetCalls, callsBefore, "no new http calls in connected state")
	end,
})

-- 15. onDisconnect() is a no-op when not connected
table.insert(tests, {
	name = "onDisconnect() is a no-op when not connected",
	fn = function()
		local mock = createMockCallbacks()
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)

		-- idle state
		sm:onDisconnect("test")
		assertEqual(sm:getState(), "idle")
		assertEqual(#mock.disconnectedCalls, 0)

		-- searching state
		sm:start()
		sm:onDisconnect("test")
		assertEqual(sm:getState(), "searching")
		assertEqual(#mock.disconnectedCalls, 0)
	end,
})

-- 16. start() is a no-op when not idle
table.insert(tests, {
	name = "start() is a no-op when not in idle state",
	fn = function()
		local mock = createMockCallbacks()
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		assertEqual(sm:getState(), "searching")
		local changesBefore = #mock.stateChanges
		sm:start() -- should be no-op
		assertEqual(#mock.stateChanges, changesBefore)
		assertEqual(sm:getState(), "searching")
	end,
})

-- 17. Connecting fails then goes back to searching
table.insert(tests, {
	name = "connectWebSocket failure returns to searching",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = false, connection = nil }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:tick(2000)
		-- Should be: searching -> connecting -> searching (ws failed)
		assertEqual(sm:getState(), "searching")
		-- Verify the connecting -> searching transition
		local found = false
		for _, change in mock.stateChanges do
			if change.old == "connecting" and change.new == "searching" then
				found = true
				break
			end
		end
		assertTrue(found, "should transition from connecting back to searching")
	end,
})

-- 18. stop() from connected fires onDisconnected
table.insert(tests, {
	name = "stop() from connected fires onDisconnected callback",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:tick(2000)
		assertEqual(sm:getState(), "connected")

		sm:stop()
		assertEqual(sm:getState(), "idle")
		assertEqual(#mock.disconnectedCalls, 1)
		assertEqual(mock.disconnectedCalls[1], "stopped")
	end,
})

-- 19. Uses default config when none provided
table.insert(tests, {
	name = "uses default config when none provided",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(nil, mock)
		sm:start()
		-- Default pollIntervalMs is 2000, so tick(1999) should not trigger scan
		sm:tick(1999)
		-- The first scan fires immediately because start() primes elapsed.
		-- But after that initial scan, the next needs 2000ms.
		-- Since we connected on the first scan (from start()), state is connected.
		assertEqual(sm:getState(), "connected")
	end,
})

-- 20. WebSocket URL format is correct
table.insert(tests, {
	name = "WebSocket URL format is ws://localhost:{port}/plugin",
	fn = function()
		local config = {
			portRange = { min = 38741, max = 38741 },
			pollIntervalMs = 100,
			maxReconnectAttempts = 3,
			initialBackoffMs = 1000,
			maxBackoffMs = 30000,
			heartbeatIntervalMs = 5000,
		}
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = false, connection = nil }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:tick(100)
		assertTrue(#mock.connectWebSocketCalls >= 1, "should have tried to connect")
		assertEqual(mock.connectWebSocketCalls[1], "ws://localhost:38741/plugin")
	end,
})

return tests
