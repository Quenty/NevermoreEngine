--[[
	Tests for DiscoveryStateMachine.

	Covers all state transitions, port scanning, callback invocations,
	and disconnect recovery using mock callbacks.

	Since the state machine uses os.clock() for timing, tests that need
	to control timing set _nextPollAt directly on the instance.
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

-- ---------------------------------------------------------------------------
-- Mock callback factory
-- ---------------------------------------------------------------------------

local function createMockCallbacks()
	local mock = {
		stateChanges = {} :: { { old: string, new: string } },
		connectedCalls = {} :: { any },
		disconnectedCalls = {} :: { string? },
		scanPortsCalls = {} :: { { number } },
		connectWebSocketCalls = {} :: { string },
		-- Which ports respond successfully (by port number)
		respondingPorts = {} :: { [number]: string },
		-- Default: no ports respond
		defaultResponse = nil :: string?,
		wsResult = { success = false, connection = nil :: any? },
	}

	-- Mock scanPortsAsync: checks respondingPorts, returns first match
	mock.scanPortsAsync = function(ports: { number }, _timeoutSec: number): (number?, string?)
		table.insert(mock.scanPortsCalls, ports)
		for _, port in ports do
			if mock.respondingPorts[port] then
				return port, mock.respondingPorts[port]
			end
		end
		if mock.defaultResponse then
			return ports[1], mock.defaultResponse
		end
		return nil, nil
	end

	mock.connectWebSocket = function(url: string): (boolean, any?)
		table.insert(mock.connectWebSocketCalls, url)
		return mock.wsResult.success, mock.wsResult.connection
	end

	mock.onStateChange = function(oldState: string, newState: string)
		table.insert(mock.stateChanges, { old = oldState, new = newState })
	end

	mock.onConnected = function(connection: any, _port: number)
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
	pollIntervalSec = 2,
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

-- 3. Scan finds a port → triggers connecting
table.insert(tests, {
	name = "scan success triggers transition to connecting",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = false, connection = nil }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
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
		mock.defaultResponse = '{"status":"ok"}'
		local fakeConnection = { id = "conn-42" }
		mock.wsResult = { success = true, connection = fakeConnection }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected")
		assertEqual(#mock.connectedCalls, 1)
		assertEqual(mock.connectedCalls[1].id, "conn-42")
		assertEqual(mock.stateChanges[1].new, "searching")
		assertEqual(mock.stateChanges[2].new, "connecting")
		assertEqual(mock.stateChanges[3].new, "connected")
	end,
})

-- 5. onDisconnect() while connected transitions to searching
table.insert(tests, {
	name = "onDisconnect() while connected transitions to searching",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected")

		sm:onDisconnect("server closed")
		assertEqual(sm:getState(), "searching")
		assertEqual(#mock.disconnectedCalls, 1)
		assertEqual(mock.disconnectedCalls[1], "server closed")
	end,
})

-- 6. After disconnect, immediate scan on next pollAsync
table.insert(tests, {
	name = "disconnect triggers immediate scan on next pollAsync",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected", "initial connection")

		sm:onDisconnect("lost")
		assertEqual(sm:getState(), "searching", "searching immediately after disconnect")

		-- Next pollAsync should scan immediately (nextPollAt was set to 0)
		sm:pollAsync()
		assertEqual(sm:getState(), "connected", "reconnected on next poll")
		assertEqual(#mock.connectedCalls, 2, "onConnected called twice")
	end,
})

-- 7. stop() from any state transitions to idle
table.insert(tests, {
	name = "stop() from any state transitions to idle",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
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
		sm2:pollAsync()
		assertEqual(sm2:getState(), "connected")
		sm2:stop()
		assertEqual(sm2:getState(), "idle", "stop from connected")
	end,
})

-- 8. Disconnect primes immediate scan
table.insert(tests, {
	name = "disconnect skips backoff and primes immediate scan",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected")

		-- After disconnect, nextPollAt should be 0 (immediate)
		mock.defaultResponse = nil
		sm:onDisconnect("lost")
		assertEqual(sm:getState(), "searching", "searching immediately")

		local scanCallsBefore = #mock.scanPortsCalls
		sm:pollAsync()
		assertTrue(#mock.scanPortsCalls > scanCallsBefore, "scan triggered on first poll after disconnect")
	end,
})

-- 9. Port scanning passes correct port list
table.insert(tests, {
	name = "port scanning passes correct port list to scanPortsAsync",
	fn = function()
		local config = {
			portRange = { min = 38740, max = 38742 },
			pollIntervalSec = 0.1,
		}
		local mock = createMockCallbacks()
		mock.respondingPorts[38742] = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected")

		-- Verify the ports passed to scanPortsAsync
		assertTrue(#mock.scanPortsCalls >= 1, "scanPortsAsync should have been called")
		local ports = mock.scanPortsCalls[1]
		assertEqual(#ports, 3, "should receive 3 ports")
		assertEqual(ports[1], 38740)
		assertEqual(ports[2], 38741)
		assertEqual(ports[3], 38742)
	end,
})

-- 10. State change callback fires on each transition
table.insert(tests, {
	name = "state change callback fires on each transition",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)

		sm:start() -- idle -> searching
		sm:pollAsync() -- searching -> connecting -> connected

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

-- 11. scanPortsAsync receives all ports including the one that responds
table.insert(tests, {
	name = "scanPortsAsync receives all ports in range",
	fn = function()
		local config = {
			portRange = { min = 38740, max = 38745 },
			pollIntervalSec = 0.1,
		}
		local mock = createMockCallbacks()
		mock.respondingPorts[38744] = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected")

		local ports = mock.scanPortsCalls[1]
		assertEqual(#ports, 6, "should receive all 6 ports in range")
	end,
})

-- 12. First poll after start() scans immediately
table.insert(tests, {
	name = "immediate port scan after start (no delay for first scan)",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected", "should connect on first poll after start")
	end,
})

-- 13. pollAsync() is a no-op in idle state
table.insert(tests, {
	name = "pollAsync() is a no-op in idle state",
	fn = function()
		local mock = createMockCallbacks()
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:pollAsync()
		assertEqual(sm:getState(), "idle")
		assertEqual(#mock.scanPortsCalls, 0)
		assertEqual(#mock.stateChanges, 0)
	end,
})

-- 14. pollAsync() is a no-op in connected state
table.insert(tests, {
	name = "pollAsync() is a no-op in connected state",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected")

		local callsBefore = #mock.scanPortsCalls
		sm:pollAsync()
		assertEqual(sm:getState(), "connected")
		assertEqual(#mock.scanPortsCalls, callsBefore, "no new scans in connected state")
	end,
})

-- 15. onDisconnect() is a no-op when not connected
table.insert(tests, {
	name = "onDisconnect() is a no-op when not connected",
	fn = function()
		local mock = createMockCallbacks()
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)

		sm:onDisconnect("test")
		assertEqual(sm:getState(), "idle")
		assertEqual(#mock.disconnectedCalls, 0)

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
		local changesBefore = #mock.stateChanges
		sm:start()
		assertEqual(#mock.stateChanges, changesBefore)
		assertEqual(sm:getState(), "searching")
	end,
})

-- 17. Connecting fails then goes back to searching
table.insert(tests, {
	name = "connectWebSocket failure returns to searching",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = false, connection = nil }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "searching")
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
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
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
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(nil, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected")
	end,
})

-- 20. WebSocket URL format is correct
table.insert(tests, {
	name = "WebSocket URL format is ws://localhost:{port}/plugin",
	fn = function()
		local config = {
			portRange = { min = 38741, max = 38741 },
			pollIntervalSec = 0.1,
		}
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = false, connection = nil }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:pollAsync()
		assertTrue(#mock.connectWebSocketCalls >= 1, "should have tried to connect")
		assertEqual(mock.connectWebSocketCalls[1], "ws://localhost:38741/plugin")
	end,
})

-- 21. pollAsync respects nextPollAt timing (doesn't scan when not due)
table.insert(tests, {
	name = "pollAsync skips scan when nextPollAt is in the future",
	fn = function()
		local mock = createMockCallbacks()
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		-- First poll scans (nextPollAt was 0)
		sm:pollAsync()
		local callsAfterFirst = #mock.scanPortsCalls
		assertTrue(callsAfterFirst > 0, "first poll should scan")

		-- Next poll should NOT scan (nextPollAt is in the future)
		sm:pollAsync()
		assertEqual(#mock.scanPortsCalls, callsAfterFirst, "second poll should not scan yet")
	end,
})

-- 22. onDisconnect from connected transitions to searching with immediate scan
table.insert(tests, {
	name = "onDisconnect from connected transitions to searching with primed scan",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected", "initial connection")

		sm:onDisconnect("error: connection lost")
		assertEqual(sm:getState(), "searching", "state after disconnect")
		assertEqual(#mock.disconnectedCalls, 1, "onDisconnected called once")
		assertEqual(mock.disconnectedCalls[1], "error: connection lost", "disconnect reason")

		local scanCallsBefore = #mock.scanPortsCalls
		sm:pollAsync()
		assertTrue(#mock.scanPortsCalls > scanCallsBefore, "scan triggered immediately after disconnect")
	end,
})

-- 23. Full disconnect + reconnect round-trip
table.insert(tests, {
	name = "disconnect then immediate re-discovery and reconnection",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected", "initial connection")
		assertEqual(#mock.connectedCalls, 1)

		sm:onDisconnect("lost")
		sm:pollAsync()
		assertEqual(sm:getState(), "connected", "reconnected after re-discovery")
		assertEqual(#mock.connectedCalls, 2, "onConnected called again")
	end,
})

-- 24. onDisconnect is no-op when not in connected state
table.insert(tests, {
	name = "onDisconnect is no-op when not in connected state",
	fn = function()
		local mock = createMockCallbacks()
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)

		sm:onDisconnect("some reason")
		assertEqual(sm:getState(), "idle", "idle unchanged")
		assertEqual(#mock.disconnectedCalls, 0)

		sm:start()
		sm:onDisconnect("some reason")
		assertEqual(sm:getState(), "searching", "searching unchanged")
		assertEqual(#mock.disconnectedCalls, 0)
	end,
})

-- 25. scanPortsAsync callback is used when provided
table.insert(tests, {
	name = "scanPortsAsync callback is used when provided",
	fn = function()
		local config = {
			portRange = { min = 38741, max = 38744 },
			pollIntervalSec = 0.1,
		}
		local mock = createMockCallbacks()
		local scanPortsCalled = false
		local scannedPorts: { number } = {}

		mock.scanPortsAsync = function(ports: { number }): (number?, string?)
			scanPortsCalled = true
			scannedPorts = ports
			return 38743, '{"status":"ok"}'
		end

		mock.wsResult = { success = true, connection = { id = "ws-scan" } }
		local sm = DiscoveryStateMachine.new(config, mock)
		sm:start()
		sm:pollAsync()

		assertTrue(scanPortsCalled, "scanPortsAsync should have been called")
		assertEqual(#scannedPorts, 4, "should receive all 4 ports")
		assertEqual(sm:getState(), "connected", "should connect via scanPortsAsync result")
		assertEqual(#mock.scanPortsCalls, 0, "default scanPortsAsync not called when overridden")
	end,
})

-- 26. scanPortsAsync returns nil when no port found
table.insert(tests, {
	name = "scanPortsAsync returning nil stays in searching",
	fn = function()
		local mock = createMockCallbacks()

		mock.scanPortsAsync = function(_ports: { number }): (number?, string?)
			return nil, nil
		end

		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "searching", "stays searching when scanPortsAsync finds nothing")
	end,
})

-- 27. stop() from connected fires onDisconnected callback
table.insert(tests, {
	name = "stop() from connected fires onDisconnected",
	fn = function()
		local mock = createMockCallbacks()
		mock.defaultResponse = '{"status":"ok"}'
		mock.wsResult = { success = true, connection = { id = "ws-1" } }
		local sm = DiscoveryStateMachine.new(TEST_CONFIG, mock)
		sm:start()
		sm:pollAsync()
		sm:stop()
		assertEqual(sm:getState(), "idle")
		assertTrue(#mock.disconnectedCalls >= 1, "onDisconnected called")
		assertEqual(mock.disconnectedCalls[#mock.disconnectedCalls], "stopped")
	end,
})

return tests
