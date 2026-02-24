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
		error(string.format("%sexpected truthy value, got %s", if label then label .. ": " else "", tostring(value)))
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

-- 5. onDisconnect() while connected transitions to searching (immediate retry)
table.insert(tests, {
	name = "onDisconnect() while connected transitions to searching",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:tick(2000)
		assertEqual(sm:getState(), "connected")

		sm:onDisconnect("server closed")
		assertEqual(sm:getState(), "searching")
		assertEqual(#mock.disconnectedCalls, 1)
		assertEqual(mock.disconnectedCalls[1], "server closed")
	end,
})

-- 6. After disconnect, immediate search allows fast reconnection
table.insert(tests, {
	name = "disconnect triggers immediate search without backoff",
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

		-- Disconnect goes straight to searching (no backoff)
		sm:onDisconnect("lost")
		assertEqual(sm:getState(), "searching", "searching immediately after disconnect")

		-- First tick triggers immediate scan (pollElapsedMs was primed)
		sm:tick(1)
		assertEqual(sm:getState(), "connected", "reconnected on first scan")
		assertEqual(#mock.connectedCalls, 2, "onConnected called twice")
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

		-- stop from searching (after disconnect)
		local sm3 = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm3:start()
		sm3:tick(2000)
		assertEqual(sm3:getState(), "connected")
		sm3:onDisconnect("lost")
		assertEqual(sm3:getState(), "searching", "searching after disconnect")
		sm3:stop()
		assertEqual(sm3:getState(), "idle", "stop from searching after disconnect")
	end,
})

-- 8. Disconnect goes straight to searching (no backoff delay)
table.insert(tests, {
	name = "disconnect skips backoff and primes immediate scan",
	fn = function()
		local config = {
			portRange = { min = 38740, max = 38741 },
			pollIntervalMs = 2000,
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
		sm:tick(2000)
		assertEqual(sm:getState(), "connected")

		-- After disconnect, should be in searching with pollElapsedMs primed
		mock.httpGetResult = { success = false, body = nil }
		sm:onDisconnect("lost")
		assertEqual(sm:getState(), "searching", "searching immediately")

		-- Even just 1ms tick should trigger scan (primed pollElapsedMs)
		local httpCallsBefore = #mock.httpGetCalls
		sm:tick(1)
		assertTrue(#mock.httpGetCalls > httpCallsBefore, "scan triggered on first tick after disconnect")
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

		sm:onDisconnect("lost") -- connected -> searching (immediate)

		assertEqual(#mock.stateChanges, 4)
		assertEqual(mock.stateChanges[1].old, "idle")
		assertEqual(mock.stateChanges[1].new, "searching")
		assertEqual(mock.stateChanges[2].old, "searching")
		assertEqual(mock.stateChanges[2].new, "connecting")
		assertEqual(mock.stateChanges[3].old, "connecting")
		assertEqual(mock.stateChanges[3].new, "connected")
		assertEqual(mock.stateChanges[4].old, "connected")
		assertEqual(mock.stateChanges[4].new, "searching")
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

-- ---------------------------------------------------------------------------
-- Bug 2: Plugin reentrancy and disconnect recovery tests
-- ---------------------------------------------------------------------------

-- 21. Reentrant tick during httpGet causes multiple connectWebSocket calls
table.insert(tests, {
	name = "reentrant tick during httpGet causes multiple connectWebSocket calls",
	fn = function()
		-- This documents the hazard that the caller-level reentrancy guard
		-- (in StudioBridgePlugin.server.lua) prevents. Without that guard,
		-- if Roblox's GetAsync yields and a reentrant Heartbeat fires, the
		-- state machine would process a second tick() mid-scan, leading to
		-- duplicate connectWebSocket calls.
		local config = {
			portRange = { min = 38741, max = 38741 },
			pollIntervalMs = 0,
			maxReconnectAttempts = 3,
			initialBackoffMs = 1000,
			maxBackoffMs = 30000,
			heartbeatIntervalMs = 5000,
		}

		local discovery
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		local fakeConnection = { id = "ws-reentrant" }
		mock.wsResult = { success = true, connection = fakeConnection }

		-- Allow exactly one level of reentrant tick to demonstrate the hazard
		-- without causing infinite recursion (which is what actually happens
		-- in production without the guard -- it stack-overflows).
		local reentrancyDepth = 0
		local originalHttpGet = mock.httpGet
		mock.httpGet = function(url: string): (boolean, string?)
			if reentrancyDepth == 0 then
				-- Simulate yielding: call tick again (reentrant) before returning.
				-- This models what happens when Roblox's HttpService:GetAsync yields
				-- and a Heartbeat fires during the yield.
				reentrancyDepth = reentrancyDepth + 1
				discovery:tick(1000)
				reentrancyDepth = reentrancyDepth - 1
			end
			return originalHttpGet(url)
		end

		discovery = DiscoveryStateMachine.new(config, mock)
		discovery:start()
		discovery:tick(1000)

		-- Without a reentrancy guard at the caller level, the reentrant tick()
		-- inside httpGet fires _scanPorts again while the first scan is still
		-- in progress. Both scans find the port alive and each calls
		-- connectWebSocket, resulting in more than one connection attempt.
		assertTrue(
			#mock.connectWebSocketCalls > 1,
			"expected multiple connectWebSocket calls due to reentrancy, got " .. tostring(#mock.connectWebSocketCalls)
		)
	end,
})

-- 22. tick during non-searching state is harmless
table.insert(tests, {
	name = "tick during non-searching state is harmless",
	fn = function()
		local mock = createMockCallbacks()
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)

		-- In idle state, tick should be a no-op
		sm:tick(1000)
		assertEqual(sm:getState(), "idle", "idle after tick in idle")
		assertEqual(#mock.httpGetCalls, 0, "no httpGet calls in idle")
		assertEqual(#mock.connectWebSocketCalls, 0, "no ws calls in idle")
		assertEqual(#mock.stateChanges, 0, "no state changes in idle")

		-- Transition to connected state
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		sm:start()
		sm:tick(2000)
		assertEqual(sm:getState(), "connected", "should be connected")

		local httpCallsBefore = #mock.httpGetCalls
		local wsCallsBefore = #mock.connectWebSocketCalls
		local stateChangesBefore = #mock.stateChanges

		-- In connected state, tick should be a no-op
		sm:tick(1000)
		assertEqual(sm:getState(), "connected", "still connected after tick")
		assertEqual(#mock.httpGetCalls, httpCallsBefore, "no new httpGet calls in connected")
		assertEqual(#mock.connectWebSocketCalls, wsCallsBefore, "no new ws calls in connected")
		assertEqual(#mock.stateChanges, stateChangesBefore, "no new state changes in connected")
	end,
})

-- 23. onDisconnect from connected transitions to searching immediately
table.insert(tests, {
	name = "onDisconnect from connected transitions to searching with primed scan",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:tick(2000)
		assertEqual(sm:getState(), "connected", "initial connection")

		sm:onDisconnect("error: connection lost")

		-- State should be searching (immediate, no backoff)
		assertEqual(sm:getState(), "searching", "state after disconnect")

		-- onDisconnected callback should have been called with the reason
		assertEqual(#mock.disconnectedCalls, 1, "onDisconnected called once")
		assertEqual(mock.disconnectedCalls[1], "error: connection lost", "disconnect reason")

		-- pollElapsedMs should be primed so next tick triggers scan
		local httpCallsBefore = #mock.httpGetCalls
		sm:tick(1)
		assertTrue(#mock.httpGetCalls > httpCallsBefore, "scan triggered immediately after disconnect")
	end,
})

-- 24. disconnect then re-discover and connect (full round-trip)
table.insert(tests, {
	name = "disconnect then immediate re-discovery and reconnection",
	fn = function()
		local config = {
			portRange = { min = 38741, max = 38741 },
			pollIntervalMs = 100,
			maxReconnectAttempts = 5,
			initialBackoffMs = 200,
			maxBackoffMs = 30000,
			heartbeatIntervalMs = 5000,
		}
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = true, body = '{"status":"ok"}' }
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:tick(100)
		assertEqual(sm:getState(), "connected", "initial connection")
		assertEqual(#mock.connectedCalls, 1, "onConnected called once")

		-- Disconnect goes straight to searching
		sm:onDisconnect("error: connection lost")
		assertEqual(sm:getState(), "searching", "searching after disconnect")
		assertEqual(#mock.disconnectedCalls, 1, "onDisconnected called")

		-- First tick triggers scan (pollElapsedMs primed), reconnects immediately
		sm:tick(1)
		assertEqual(sm:getState(), "connected", "reconnected after re-discovery")

		-- onConnected should have been called a second time
		assertEqual(#mock.connectedCalls, 2, "onConnected called again after reconnection")
	end,
})

-- 25. onDisconnect is no-op when not in connected state
table.insert(tests, {
	name = "onDisconnect is no-op when not in connected state",
	fn = function()
		local mock = createMockCallbacks()
		mock.httpGetResult = { success = false, body = nil }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)

		-- idle state
		sm:onDisconnect("some reason")
		assertEqual(sm:getState(), "idle", "idle unchanged")
		assertEqual(#mock.disconnectedCalls, 0, "no disconnected callback in idle")

		-- searching state
		sm:start()
		assertEqual(sm:getState(), "searching", "in searching state")
		sm:onDisconnect("some reason")
		assertEqual(sm:getState(), "searching", "searching unchanged")
		assertEqual(#mock.disconnectedCalls, 0, "no disconnected callback in searching")
	end,
})

-- ---------------------------------------------------------------------------
-- scanPorts callback tests
-- ---------------------------------------------------------------------------

-- 26. scanPorts callback is used instead of sequential httpGet
table.insert(tests, {
	name = "scanPorts callback is used when provided",
	fn = function()
		local config = {
			portRange = { min = 38741, max = 38744 },
			pollIntervalMs = 100,
			maxReconnectAttempts = 3,
			initialBackoffMs = 1000,
			maxBackoffMs = 30000,
			heartbeatIntervalMs = 5000,
		}
		local mock = createMockCallbacks()
		local scanPortsCalled = false
		local scannedPorts: { number } = {}

		mock.scanPorts = function(ports: { number }): (number?, string?)
			scanPortsCalled = true
			scannedPorts = ports
			-- Simulate finding port 38743
			return 38743, '{"status":"ok"}'
		end

		mock.wsResult = { success = true, connection = { id = "ws-scan" } }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:tick(100)

		assertTrue(scanPortsCalled, "scanPorts should have been called")
		assertEqual(#scannedPorts, 4, "should receive all 4 ports")
		assertEqual(sm:getState(), "connected", "should connect via scanPorts result")
		-- httpGet should NOT have been called (scanPorts takes precedence)
		assertEqual(#mock.httpGetCalls, 0, "httpGet not called when scanPorts is provided")
	end,
})

-- 27. scanPorts returns nil when no port found
table.insert(tests, {
	name = "scanPorts returning nil stays in searching",
	fn = function()
		local config = {
			portRange = { min = 38741, max = 38744 },
			pollIntervalMs = 100,
			maxReconnectAttempts = 3,
			initialBackoffMs = 1000,
			maxBackoffMs = 30000,
			heartbeatIntervalMs = 5000,
		}
		local mock = createMockCallbacks()

		mock.scanPorts = function(_ports: { number }): (number?, string?)
			return nil, nil
		end

		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:tick(100)
		assertEqual(sm:getState(), "searching", "stays searching when scanPorts finds nothing")
	end,
})

return tests
