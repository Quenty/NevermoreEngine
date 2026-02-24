--[[
	Integration tests for Phase 0.5 plugin modules.

	Tests that Protocol, ActionRouter, MessageBuffer, and DiscoveryStateMachine
	compose correctly as an integrated system. Each test exercises multiple modules
	together, validating the full data flow rather than individual module behavior.
]]

local ActionRouter = require("../../studio-bridge-plugin/src/Shared/ActionRouter")
local DiscoveryStateMachine = require("../../studio-bridge-plugin/src/Shared/DiscoveryStateMachine")
local MessageBuffer = require("../../studio-bridge-plugin/src/Shared/MessageBuffer")
local Protocol = require("../../studio-bridge-plugin/src/Shared/Protocol")

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

local function assertNil(value: any, label: string?)
	if value ~= nil then
		error(string.format("%sexpected nil, got %s", if label then label .. ": " else "", tostring(value)))
	end
end

local function assertNotNil(value: any, label: string?)
	if value == nil then
		error(string.format("%sexpected non-nil value", if label then label .. ": " else ""))
	end
end

local function assertTrue(value: any, label: string?)
	if not value then
		error(string.format("%sexpected truthy value, got %s", if label then label .. ": " else "", tostring(value)))
	end
end

local function assertContains(str: string, substring: string, label: string?)
	if not string.find(str, substring, 1, true) then
		error(
			string.format(
				"%sexpected string to contain '%s', got '%s'",
				if label then label .. ": " else "",
				substring,
				str
			)
		)
	end
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

local tests = {}

-- ===========================================================================
-- 1. Protocol + ActionRouter: encode request, decode, dispatch, encode response
-- ===========================================================================

table.insert(tests, {
	name = "Protocol + ActionRouter: queryState round-trip through dispatch",
	fn = function()
		-- Set up a router with a queryState handler
		local router = ActionRouter.new()
		router:register("queryState", function(_payload, _requestId, _sessionId)
			return { state = "Edit", placeId = 12345, placeName = "TestPlace", gameId = 67890 }
		end)

		-- Encode a queryState request using Protocol
		local encoded = Protocol.encode({
			type = "queryState",
			sessionId = "int-sess-001",
			requestId = "int-req-001",
			payload = {},
		})

		-- Decode it back
		local decoded, decodeErr = Protocol.decode(encoded)
		assertNil(decodeErr, "decode error")
		assertNotNil(decoded, "decoded message")
		assertEqual(decoded.type, "queryState")
		assertEqual(decoded.sessionId, "int-sess-001")
		assertEqual(decoded.requestId, "int-req-001")

		-- Dispatch through ActionRouter
		local response = router:dispatch(decoded)
		assertNotNil(response, "dispatch response")
		assertEqual(response.type, "stateResult")
		assertEqual(response.sessionId, "int-sess-001")
		assertEqual(response.requestId, "int-req-001")
		assertEqual(response.payload.state, "Edit")
		assertEqual(response.payload.placeId, 12345)

		-- Encode the response back through Protocol
		local responseEncoded = Protocol.encode({
			type = response.type,
			sessionId = response.sessionId,
			requestId = response.requestId,
			payload = response.payload,
		})

		-- Decode the response to verify it round-trips cleanly
		local responseParsed, respErr = Protocol.decode(responseEncoded)
		assertNil(respErr, "response decode error")
		assertNotNil(responseParsed, "response parsed")
		assertEqual(responseParsed.type, "stateResult")
		assertEqual(responseParsed.payload.state, "Edit")
		assertEqual(responseParsed.payload.placeName, "TestPlace")
	end,
})

-- ===========================================================================
-- 2. Protocol + ActionRouter: execute action with scriptComplete response
-- ===========================================================================

table.insert(tests, {
	name = "Protocol + ActionRouter: execute round-trip produces scriptComplete",
	fn = function()
		local router = ActionRouter.new()
		local capturedScript = nil

		router:register("execute", function(payload, _requestId, _sessionId)
			capturedScript = payload.script
			return { success = true }
		end)

		-- Simulate server sending an execute message
		local executeMsg = Protocol.encode({
			type = "execute",
			sessionId = "exec-sess",
			requestId = "exec-req-001",
			payload = { script = "print('hello world')" },
		})

		-- Decode and dispatch
		local decoded, err = Protocol.decode(executeMsg)
		assertNil(err, "decode error")
		local response = router:dispatch(decoded)

		-- Verify handler received the script
		assertEqual(capturedScript, "print('hello world')", "handler received script")

		-- Verify response is scriptComplete
		assertNotNil(response, "response")
		assertEqual(response.type, "scriptComplete")
		assertEqual(response.payload.success, true)
		assertEqual(response.requestId, "exec-req-001")

		-- Re-encode and verify the scriptComplete round-trips
		local responseJson = Protocol.encode({
			type = response.type,
			sessionId = response.sessionId,
			requestId = response.requestId,
			payload = response.payload,
		})
		local reparsed, rerr = Protocol.decode(responseJson)
		assertNil(rerr, "re-decode error")
		assertEqual(reparsed.type, "scriptComplete")
		assertEqual(reparsed.payload.success, true)
	end,
})

-- ===========================================================================
-- 3. ActionRouter + MessageBuffer: queryLogs reads from buffer
-- ===========================================================================

table.insert(tests, {
	name = "ActionRouter + MessageBuffer: queryLogs handler reads from buffer",
	fn = function()
		local buffer = MessageBuffer.new(100)
		local router = ActionRouter.new()

		-- Register a queryLogs handler that reads from the buffer
		router:register("queryLogs", function(payload, _requestId, _sessionId)
			local direction = payload.direction or "tail"
			local count = payload.count or 50
			return buffer:get(direction, count)
		end)

		-- Push log entries
		buffer:push({ level = "Print", body = "Starting up...", timestamp = 1000 })
		buffer:push({ level = "Warning", body = "Low memory", timestamp = 2000 })
		buffer:push({ level = "Error", body = "Connection failed", timestamp = 3000 })
		buffer:push({ level = "Print", body = "Retrying...", timestamp = 4000 })
		buffer:push({ level = "Print", body = "Connected!", timestamp = 5000 })

		-- Dispatch a queryLogs request for tail 3
		local response = router:dispatch({
			type = "queryLogs",
			sessionId = "logs-sess",
			requestId = "logs-req-001",
			payload = { direction = "tail", count = 3 },
		})

		assertNotNil(response, "response")
		assertEqual(response.type, "logsResult")
		assertEqual(#response.payload.entries, 3)
		assertEqual(response.payload.entries[1].body, "Connection failed")
		assertEqual(response.payload.entries[2].body, "Retrying...")
		assertEqual(response.payload.entries[3].body, "Connected!")
		assertEqual(response.payload.total, 5)
		assertEqual(response.payload.bufferCapacity, 100)

		-- Now request head 2
		local headResponse = router:dispatch({
			type = "queryLogs",
			sessionId = "logs-sess",
			requestId = "logs-req-002",
			payload = { direction = "head", count = 2 },
		})

		assertNotNil(headResponse, "head response")
		assertEqual(#headResponse.payload.entries, 2)
		assertEqual(headResponse.payload.entries[1].body, "Starting up...")
		assertEqual(headResponse.payload.entries[2].body, "Low memory")
	end,
})

-- ===========================================================================
-- 4. Protocol + ActionRouter + MessageBuffer: queryLogs wire round-trip
-- ===========================================================================

table.insert(tests, {
	name = "Protocol + ActionRouter + MessageBuffer: queryLogs full wire round-trip",
	fn = function()
		local buffer = MessageBuffer.new(50)
		local router = ActionRouter.new()

		router:register("queryLogs", function(payload, _requestId, _sessionId)
			return buffer:get(payload.direction, payload.count)
		end)

		-- Push entries
		for i = 1, 10 do
			buffer:push({
				level = if i % 3 == 0 then "Warning" else "Print",
				body = "log entry " .. tostring(i),
				timestamp = i * 1000,
			})
		end

		-- Encode queryLogs request
		local requestJson = Protocol.encode({
			type = "queryLogs",
			sessionId = "wire-sess",
			requestId = "wire-req-001",
			payload = { direction = "tail", count = 5 },
		})

		-- Decode request
		local request, decErr = Protocol.decode(requestJson)
		assertNil(decErr, "decode error")

		-- Dispatch
		local response = router:dispatch(request)
		assertNotNil(response, "response")

		-- Encode response
		local responseJson = Protocol.encode({
			type = response.type,
			sessionId = response.sessionId,
			requestId = response.requestId,
			payload = response.payload,
		})

		-- Decode response
		local responseParsed, respErr = Protocol.decode(responseJson)
		assertNil(respErr, "response decode error")
		assertEqual(responseParsed.type, "logsResult")
		assertEqual(#responseParsed.payload.entries, 5)
		assertEqual(responseParsed.payload.entries[5].body, "log entry 10")
		assertEqual(responseParsed.payload.total, 10)
		assertEqual(responseParsed.payload.bufferCapacity, 50)
	end,
})

-- ===========================================================================
-- 5. DiscoveryStateMachine + Protocol: health check and connection lifecycle
-- ===========================================================================

table.insert(tests, {
	name = "DiscoveryStateMachine + Protocol: full discovery to connected lifecycle",
	fn = function()
		local stateTransitions: { { old: string, new: string } } = {}
		local connectedConnection = nil
		local disconnectedReason = nil
		local targetPort = 38745

		local sm = DiscoveryStateMachine.new({
			portRange = { min = 38740, max = 38759 },
			pollIntervalSec = 1,
		}, {
			scanPortsAsync = function(ports: { number }, _timeoutSec: number): (number?, string?)
				-- Simulate: only the target port responds
				for _, port in ports do
					if port == targetPort then
						local healthBody = Protocol.encode({
							type = "welcome",
							sessionId = "health-check",
							payload = { sessionId = "health-check" },
							protocolVersion = 2,
						})
						return port, healthBody
					end
				end
				return nil, nil
			end,
			connectWebSocket = function(url: string)
				-- Simulate: WebSocket connection succeeds for the target port
				if string.find(url, tostring(targetPort)) then
					return true, { id = "mock-connection" }
				end
				return false, nil
			end,
			onStateChange = function(oldState: string, newState: string)
				table.insert(stateTransitions, { old = oldState, new = newState })
			end,
			onConnected = function(connection: any)
				connectedConnection = connection
			end,
			onDisconnected = function(reason: string?)
				disconnectedReason = reason
			end,
		})

		-- Start the state machine
		assertEqual(sm:getState(), "idle")
		sm:start()
		assertEqual(sm:getState(), "searching")

		-- First poll triggers immediate scan (nextPollAt was set to 0)
		sm:pollAsync()

		-- State machine should have found the port and connected
		assertEqual(sm:getState(), "connected")
		assertNotNil(connectedConnection, "connection object")
		assertEqual(connectedConnection.id, "mock-connection")

		-- Verify state transitions: idle -> searching -> connecting -> connected
		assertTrue(#stateTransitions >= 3, "at least 3 transitions")
		assertEqual(stateTransitions[1].old, "idle")
		assertEqual(stateTransitions[1].new, "searching")
		assertEqual(stateTransitions[2].old, "searching")
		assertEqual(stateTransitions[2].new, "connecting")
		assertEqual(stateTransitions[3].old, "connecting")
		assertEqual(stateTransitions[3].new, "connected")
	end,
})

-- ===========================================================================
-- 6. DiscoveryStateMachine: disconnect triggers immediate search and recovers
-- ===========================================================================

table.insert(tests, {
	name = "DiscoveryStateMachine: disconnect searches immediately and reconnects when server returns",
	fn = function()
		local currentState = "idle"
		local connectAttempts = 0
		local scanAttempts = 0
		local serverUp = true

		local sm = DiscoveryStateMachine.new({
			portRange = { min = 38740, max = 38740 }, -- single port
			pollIntervalSec = 0.1,
		}, {
			scanPortsAsync = function(ports: { number }, _timeoutSec: number): (number?, string?)
				scanAttempts = scanAttempts + 1
				if serverUp then
					return ports[1], "ok"
				end
				return nil, nil
			end,
			connectWebSocket = function(_url: string)
				connectAttempts = connectAttempts + 1
				if serverUp then
					return true, { id = "conn" }
				end
				return false, nil
			end,
			onStateChange = function(_old: string, new: string)
				currentState = new
			end,
			onConnected = function(_conn: any) end,
			onDisconnected = function(_reason: string?) end,
		})

		-- Start and connect
		sm:start()
		sm:pollAsync()
		assertEqual(currentState, "connected", "initial connection")

		-- Simulate disconnect with server down
		serverUp = false
		sm:onDisconnect("connection lost")
		-- Transitions straight to searching (no backoff)
		assertEqual(currentState, "searching", "searching immediately after disconnect")

		-- First poll triggers scan (primed), server still down -> stays searching
		sm:pollAsync()
		assertEqual(currentState, "searching", "stays searching when server is down")

		-- Next poll should not scan yet (nextPollAt is in the future)
		sm:pollAsync()
		assertEqual(currentState, "searching", "still searching, waiting for poll interval")

		-- Bring server back up and force next poll by setting _nextPollAt to 0
		serverUp = true
		sm._nextPollAt = 0

		-- Next poll triggers scan -> server responds -> connects
		sm:pollAsync()
		assertEqual(currentState, "connected", "reconnected after server came back")
	end,
})

-- ===========================================================================
-- 7. Full message lifecycle: register -> welcome -> execute -> output -> scriptComplete
-- ===========================================================================

table.insert(tests, {
	name = "Full lifecycle: register -> welcome -> execute -> output -> scriptComplete",
	fn = function()
		local sessionId = "lifecycle-sess-001"
		local router = ActionRouter.new()
		local outputBuffer = MessageBuffer.new(100)

		-- Set up execute handler that simulates script execution
		router:register("execute", function(payload, _requestId, _sessionId)
			-- Simulate: script produces output and completes
			outputBuffer:push({
				level = "Print",
				body = "Script output: " .. payload.script,
				timestamp = 5000,
			})
			return { success = true }
		end)

		-- Step 1: Plugin sends register
		local registerMsg = Protocol.encode({
			type = "register",
			sessionId = sessionId,
			protocolVersion = 2,
			payload = {
				pluginVersion = "1.0.0",
				instanceId = "inst-abc",
				placeName = "TestPlace",
				state = "Edit",
				capabilities = { "execute", "queryState", "queryLogs" },
			},
		})

		local registerDecoded, regErr = Protocol.decode(registerMsg)
		assertNil(regErr, "register decode error")
		assertEqual(registerDecoded.type, "register")
		assertEqual(registerDecoded.protocolVersion, 2)
		assertEqual(registerDecoded.payload.pluginVersion, "1.0.0")

		-- Step 2: Server sends welcome
		local welcomeMsg = Protocol.encode({
			type = "welcome",
			sessionId = sessionId,
			protocolVersion = 2,
			payload = {
				sessionId = sessionId,
				capabilities = { "execute", "queryState", "queryLogs" },
			},
		})

		local welcomeDecoded, welErr = Protocol.decode(welcomeMsg)
		assertNil(welErr, "welcome decode error")
		assertEqual(welcomeDecoded.type, "welcome")
		assertEqual(welcomeDecoded.protocolVersion, 2)
		assertEqual(welcomeDecoded.payload.sessionId, sessionId)

		-- Step 3: Server sends execute
		local executeMsg = Protocol.encode({
			type = "execute",
			sessionId = sessionId,
			requestId = "req-exec-001",
			payload = { script = "print('hello')" },
		})

		local executeDecoded, execErr = Protocol.decode(executeMsg)
		assertNil(execErr, "execute decode error")

		-- Step 4: Plugin dispatches execute through ActionRouter
		local scriptCompleteResponse = router:dispatch(executeDecoded)
		assertNotNil(scriptCompleteResponse, "scriptComplete response")
		assertEqual(scriptCompleteResponse.type, "scriptComplete")
		assertEqual(scriptCompleteResponse.payload.success, true)
		assertEqual(scriptCompleteResponse.requestId, "req-exec-001")

		-- Step 5: Verify output was buffered
		assertEqual(outputBuffer:size(), 1, "one output entry")
		local logs = outputBuffer:get("tail", 1)
		assertContains(logs.entries[1].body, "print('hello')")

		-- Step 6: Encode the output message (as plugin would send it)
		local outputMsg = Protocol.encode({
			type = "output",
			sessionId = sessionId,
			payload = {
				messages = {
					{ level = "Print", body = logs.entries[1].body },
				},
			},
		})

		local outputDecoded, outErr = Protocol.decode(outputMsg)
		assertNil(outErr, "output decode error")
		assertEqual(outputDecoded.type, "output")
		assertEqual(#outputDecoded.payload.messages, 1)

		-- Step 7: Encode the scriptComplete response
		local completeMsg = Protocol.encode({
			type = scriptCompleteResponse.type,
			sessionId = scriptCompleteResponse.sessionId,
			requestId = scriptCompleteResponse.requestId,
			payload = scriptCompleteResponse.payload,
		})

		local completeParsed, compErr = Protocol.decode(completeMsg)
		assertNil(compErr, "scriptComplete decode error")
		assertEqual(completeParsed.type, "scriptComplete")
		assertEqual(completeParsed.payload.success, true)
	end,
})

-- ===========================================================================
-- 8. ActionRouter error dispatch round-trips through Protocol
-- ===========================================================================

table.insert(tests, {
	name = "Protocol + ActionRouter: error response round-trips through Protocol",
	fn = function()
		local router = ActionRouter.new()

		-- No handler registered: should produce UNKNOWN_REQUEST error
		local unknownRequest = Protocol.encode({
			type = "captureScreenshot",
			sessionId = "err-sess",
			requestId = "err-req-001",
			payload = {},
		})

		local decoded, err = Protocol.decode(unknownRequest)
		assertNil(err, "decode error")

		local errorResponse = router:dispatch(decoded)
		assertNotNil(errorResponse, "error response")
		assertEqual(errorResponse.type, "error")
		assertEqual(errorResponse.payload.code, "UNKNOWN_REQUEST")

		-- Encode the error response and verify it round-trips
		local errorJson = Protocol.encode({
			type = errorResponse.type,
			sessionId = errorResponse.sessionId,
			requestId = errorResponse.requestId,
			payload = errorResponse.payload,
		})

		local errorParsed, errParseErr = Protocol.decode(errorJson)
		assertNil(errParseErr, "error parse error")
		assertEqual(errorParsed.type, "error")
		assertEqual(errorParsed.payload.code, "UNKNOWN_REQUEST")
		assertContains(errorParsed.payload.message, "captureScreenshot")
	end,
})

-- ===========================================================================
-- 9. ActionRouter + MessageBuffer: buffer overflow during queryLogs
-- ===========================================================================

table.insert(tests, {
	name = "ActionRouter + MessageBuffer: queryLogs with buffer overflow returns newest",
	fn = function()
		local buffer = MessageBuffer.new(5) -- small capacity
		local router = ActionRouter.new()

		router:register("queryLogs", function(payload, _requestId, _sessionId)
			return buffer:get(payload.direction, payload.count)
		end)

		-- Push more entries than capacity
		for i = 1, 20 do
			buffer:push({
				level = if i % 2 == 0 then "Warning" else "Print",
				body = "overflow-" .. tostring(i),
				timestamp = i * 100,
			})
		end

		-- Query tail 3 via dispatch
		local response = router:dispatch({
			type = "queryLogs",
			sessionId = "overflow-sess",
			requestId = "overflow-req",
			payload = { direction = "tail", count = 3 },
		})

		assertNotNil(response, "response")
		assertEqual(response.type, "logsResult")
		assertEqual(#response.payload.entries, 3)
		-- Should be the last 3 of the most recent 5 (16..20)
		assertEqual(response.payload.entries[1].body, "overflow-18")
		assertEqual(response.payload.entries[2].body, "overflow-19")
		assertEqual(response.payload.entries[3].body, "overflow-20")
		assertEqual(response.payload.total, 5, "total reflects buffer count (capped at capacity)")
		assertEqual(response.payload.bufferCapacity, 5)
	end,
})

-- ===========================================================================
-- 10. Multiple actions dispatched concurrently through Protocol
-- ===========================================================================

table.insert(tests, {
	name = "Protocol + ActionRouter: multiple concurrent requests maintain isolation",
	fn = function()
		local buffer = MessageBuffer.new(100)
		local router = ActionRouter.new()

		-- Register multiple handlers
		router:register("queryState", function(_payload, _requestId, _sessionId)
			return { state = "Play", placeId = 111, placeName = "GamePlace", gameId = 222 }
		end)

		router:register("queryLogs", function(payload, _requestId, _sessionId)
			return buffer:get(payload.direction, payload.count)
		end)

		router:register("execute", function(payload, _requestId, _sessionId)
			return { success = true }
		end)

		-- Push some logs
		buffer:push({ level = "Print", body = "test log", timestamp = 1000 })

		-- Encode three requests with different requestIds
		local requests = {
			Protocol.encode({
				type = "queryState",
				sessionId = "multi-sess",
				requestId = "multi-req-001",
				payload = {},
			}),
			Protocol.encode({
				type = "execute",
				sessionId = "multi-sess",
				requestId = "multi-req-002",
				payload = { script = "game:GetService('Workspace')" },
			}),
			Protocol.encode({
				type = "queryLogs",
				sessionId = "multi-sess",
				requestId = "multi-req-003",
				payload = { direction = "tail", count = 10 },
			}),
		}

		-- Decode and dispatch all three
		local responses = {}
		for _, reqJson in requests do
			local decoded, err = Protocol.decode(reqJson)
			assertNil(err, "decode error")
			local resp = router:dispatch(decoded)
			assertNotNil(resp, "response")
			table.insert(responses, resp)
		end

		-- Verify each response has correct type and requestId
		assertEqual(responses[1].type, "stateResult")
		assertEqual(responses[1].requestId, "multi-req-001")
		assertEqual(responses[1].payload.state, "Play")

		assertEqual(responses[2].type, "scriptComplete")
		assertEqual(responses[2].requestId, "multi-req-002")
		assertEqual(responses[2].payload.success, true)

		assertEqual(responses[3].type, "logsResult")
		assertEqual(responses[3].requestId, "multi-req-003")
		assertEqual(#responses[3].payload.entries, 1)
		assertEqual(responses[3].payload.entries[1].body, "test log")

		-- All share the same sessionId
		for _, resp in responses do
			assertEqual(resp.sessionId, "multi-sess")
		end
	end,
})

-- ===========================================================================
-- 11. DiscoveryStateMachine + Protocol: stop during connection cleans up
-- ===========================================================================

table.insert(tests, {
	name = "DiscoveryStateMachine: stop during connected state fires onDisconnected",
	fn = function()
		local disconnectReason: string? = nil
		local wasConnected = false

		local sm = DiscoveryStateMachine.new({
			portRange = { min = 38740, max = 38740 },
			pollIntervalSec = 0.1,
		}, {
			scanPortsAsync = function(ports: { number }, _timeoutSec: number): (number?, string?)
				return ports[1], "ok"
			end,
			connectWebSocket = function(_url: string)
				return true, { id = "conn-stop-test" }
			end,
			onStateChange = function(_old: string, _new: string) end,
			onConnected = function(_conn: any)
				wasConnected = true
			end,
			onDisconnected = function(reason: string?)
				disconnectReason = reason
			end,
		})

		-- Connect
		sm:start()
		sm:pollAsync()
		assertTrue(wasConnected, "should be connected")
		assertEqual(sm:getState(), "connected")

		-- Stop while connected
		sm:stop()
		assertEqual(sm:getState(), "idle")
		assertEqual(disconnectReason, "stopped", "disconnect reason should be 'stopped'")
	end,
})

-- ===========================================================================
-- 12. Protocol + ActionRouter: handler error produces encodable error message
-- ===========================================================================

table.insert(tests, {
	name = "Protocol + ActionRouter: handler error encodes as valid Protocol error",
	fn = function()
		local router = ActionRouter.new()
		router:register("queryDataModel", function(_payload, _requestId, _sessionId)
			error("Instance not found: game.Workspace.Missing")
		end)

		-- Encode request
		local requestJson = Protocol.encode({
			type = "queryDataModel",
			sessionId = "err-handler-sess",
			requestId = "err-handler-req",
			payload = { path = "game.Workspace.Missing", depth = 0 },
		})

		-- Decode and dispatch
		local decoded, decErr = Protocol.decode(requestJson)
		assertNil(decErr, "decode error")

		local errorResponse = router:dispatch(decoded)
		assertNotNil(errorResponse, "error response")
		assertEqual(errorResponse.type, "error")
		assertEqual(errorResponse.payload.code, "INTERNAL_ERROR")

		-- Encode the error through Protocol
		local errorJson = Protocol.encode({
			type = errorResponse.type,
			sessionId = errorResponse.sessionId,
			requestId = errorResponse.requestId,
			payload = errorResponse.payload,
		})

		-- Verify it decodes cleanly
		local errorParsed, parseErr = Protocol.decode(errorJson)
		assertNil(parseErr, "error decode error")
		assertEqual(errorParsed.type, "error")
		assertEqual(errorParsed.payload.code, "INTERNAL_ERROR")
		assertContains(errorParsed.payload.message, "Instance not found")
		assertEqual(errorParsed.sessionId, "err-handler-sess")
		assertEqual(errorParsed.requestId, "err-handler-req")
	end,
})

-- ===========================================================================
-- 13. Full system: discovery -> register -> queryLogs with buffered data
-- ===========================================================================

table.insert(tests, {
	name = "Full system: discovery + register + queryLogs with populated buffer",
	fn = function()
		-- Set up the message buffer and router as if a plugin were running
		local buffer = MessageBuffer.new(100)
		local router = ActionRouter.new()
		local discoveredPort: number? = nil

		router:register("queryLogs", function(payload, _requestId, _sessionId)
			return buffer:get(payload.direction or "tail", payload.count or 50)
		end)

		-- Pre-populate the buffer (simulating logs accumulated during startup)
		buffer:push({ level = "Print", body = "[StudioBridge] Plugin loaded", timestamp = 100 })
		buffer:push({ level = "Print", body = "[StudioBridge] Searching for server...", timestamp = 200 })
		buffer:push({ level = "Print", body = "[StudioBridge] Connected to port 38742", timestamp = 500 })

		-- Discovery finds the server on port 38742
		local sm = DiscoveryStateMachine.new({
			portRange = { min = 38740, max = 38750 },
			pollIntervalSec = 0.5,
		}, {
			scanPortsAsync = function(ports: { number }, _timeoutSec: number): (number?, string?)
				for _, port in ports do
					if port == 38742 then
						return port, '{"status":"ok"}'
					end
				end
				return nil, nil
			end,
			connectWebSocket = function(url: string)
				if string.find(url, "38742") then
					discoveredPort = 38742
					return true, { id = "ws-conn" }
				end
				return false, nil
			end,
			onStateChange = function(_old: string, _new: string) end,
			onConnected = function(_conn: any) end,
			onDisconnected = function(_reason: string?) end,
		})

		sm:start()
		sm:pollAsync()
		assertEqual(sm:getState(), "connected")
		assertEqual(discoveredPort, 38742)

		-- Now simulate register + welcome handshake via Protocol
		local registerJson = Protocol.encode({
			type = "register",
			sessionId = "full-sys-sess",
			protocolVersion = 2,
			payload = {
				pluginVersion = "1.0.0",
				instanceId = "inst-full",
				placeName = "FullTestPlace",
				state = "Edit",
				capabilities = { "execute", "queryLogs" },
			},
		})

		local registerDecoded, regErr = Protocol.decode(registerJson)
		assertNil(regErr, "register decode error")
		assertEqual(registerDecoded.type, "register")

		-- Server sends welcome
		local welcomeJson = Protocol.encode({
			type = "welcome",
			sessionId = "full-sys-sess",
			protocolVersion = 2,
			payload = { sessionId = "full-sys-sess" },
		})
		local welcomeDecoded, welErr = Protocol.decode(welcomeJson)
		assertNil(welErr, "welcome decode error")
		assertEqual(welcomeDecoded.type, "welcome")

		-- Server sends queryLogs
		local queryLogsJson = Protocol.encode({
			type = "queryLogs",
			sessionId = "full-sys-sess",
			requestId = "ql-001",
			payload = { direction = "tail", count = 2 },
		})

		local queryDecoded, qlErr = Protocol.decode(queryLogsJson)
		assertNil(qlErr, "queryLogs decode error")

		-- Plugin dispatches through router
		local logsResponse = router:dispatch(queryDecoded)
		assertNotNil(logsResponse, "logs response")
		assertEqual(logsResponse.type, "logsResult")
		assertEqual(#logsResponse.payload.entries, 2)
		-- Last 2 entries
		assertContains(logsResponse.payload.entries[1].body, "Searching for server")
		assertContains(logsResponse.payload.entries[2].body, "Connected to port 38742")
		assertEqual(logsResponse.payload.total, 3)
	end,
})

-- ===========================================================================
-- 14. Protocol validates v2 handshake fields in register/welcome cycle
-- ===========================================================================

table.insert(tests, {
	name = "Protocol: register and welcome preserve protocolVersion and capabilities",
	fn = function()
		-- Test that protocolVersion survives the encode/decode round-trip
		local capabilities =
			{ "execute", "queryState", "captureScreenshot", "queryDataModel", "queryLogs", "subscribe", "heartbeat" }

		local registerJson = Protocol.encode({
			type = "register",
			sessionId = "v2-test-sess",
			protocolVersion = 2,
			payload = {
				pluginVersion = "1.2.3",
				instanceId = "inst-v2",
				placeName = "V2Place",
				state = "Edit",
				capabilities = capabilities,
			},
		})

		local registerParsed, regErr = Protocol.decode(registerJson)
		assertNil(regErr, "register error")
		assertEqual(registerParsed.protocolVersion, 2)
		assertEqual(registerParsed.payload.pluginVersion, "1.2.3")
		assertEqual(registerParsed.payload.instanceId, "inst-v2")
		assertEqual(#registerParsed.payload.capabilities, 7)

		-- Welcome with protocolVersion
		local welcomeJson = Protocol.encode({
			type = "welcome",
			sessionId = "v2-test-sess",
			protocolVersion = 2,
			payload = {
				sessionId = "v2-test-sess",
				capabilities = capabilities,
			},
		})

		local welcomeParsed, welErr = Protocol.decode(welcomeJson)
		assertNil(welErr, "welcome error")
		assertEqual(welcomeParsed.protocolVersion, 2)
		assertEqual(welcomeParsed.payload.sessionId, "v2-test-sess")
		assertEqual(#welcomeParsed.payload.capabilities, 7)
	end,
})

-- ===========================================================================
-- 15. DiscoveryStateMachine: all ports fail, stays searching
-- ===========================================================================

table.insert(tests, {
	name = "DiscoveryStateMachine: all ports fail stays in searching state",
	fn = function()
		local currentState = "idle"
		local sm = DiscoveryStateMachine.new({
			portRange = { min = 38740, max = 38742 }, -- 3 ports
			pollIntervalSec = 0.5,
		}, {
			scanPortsAsync = function(_ports: { number }, _timeoutSec: number): (number?, string?)
				return nil, nil -- all ports fail
			end,
			connectWebSocket = function(_url: string)
				return false, nil
			end,
			onStateChange = function(_old: string, new: string)
				currentState = new
			end,
			onConnected = function(_conn: any) end,
			onDisconnected = function(_reason: string?) end,
		})

		sm:start()
		assertEqual(currentState, "searching")

		-- Poll to trigger scan
		sm:pollAsync()
		-- All ports failed, should stay in searching
		assertEqual(currentState, "searching")

		-- Next poll should skip (nextPollAt is in the future), then force it
		sm._nextPollAt = 0
		sm:pollAsync()
		assertEqual(currentState, "searching", "still searching after second scan")
	end,
})

-- ===========================================================================
-- 16. ActionRouter + Protocol: subscribe/unsubscribe flow
-- ===========================================================================

table.insert(tests, {
	name = "Protocol + ActionRouter: subscribe and unsubscribe flow",
	fn = function()
		local router = ActionRouter.new()
		local activeSubscriptions: { string } = {}

		router:register("subscribe", function(payload, _requestId, _sessionId)
			for _, event in payload.events do
				table.insert(activeSubscriptions, event)
			end
			return { events = payload.events }
		end)

		router:register("unsubscribe", function(payload, _requestId, _sessionId)
			local remaining = {}
			for _, sub in activeSubscriptions do
				local found = false
				for _, unsub in payload.events do
					if sub == unsub then
						found = true
						break
					end
				end
				if not found then
					table.insert(remaining, sub)
				end
			end
			activeSubscriptions = remaining
			return { events = payload.events }
		end)

		-- Subscribe via Protocol-encoded message
		local subJson = Protocol.encode({
			type = "subscribe",
			sessionId = "sub-sess",
			requestId = "sub-req-001",
			payload = { events = { "stateChange", "logPush" } },
		})

		local subDecoded, subErr = Protocol.decode(subJson)
		assertNil(subErr, "subscribe decode error")
		local subResponse = router:dispatch(subDecoded)

		assertNotNil(subResponse, "subscribe response")
		assertEqual(subResponse.type, "subscribeResult")
		assertEqual(#activeSubscriptions, 2)

		-- Encode the subscribeResult and verify round-trip
		local subResultJson = Protocol.encode({
			type = subResponse.type,
			sessionId = subResponse.sessionId,
			requestId = subResponse.requestId,
			payload = subResponse.payload,
		})
		local subResultParsed, srErr = Protocol.decode(subResultJson)
		assertNil(srErr, "subscribeResult decode error")
		assertEqual(subResultParsed.type, "subscribeResult")

		-- Unsubscribe from stateChange
		local unsubJson = Protocol.encode({
			type = "unsubscribe",
			sessionId = "sub-sess",
			requestId = "sub-req-002",
			payload = { events = { "stateChange" } },
		})

		local unsubDecoded, unsubErr = Protocol.decode(unsubJson)
		assertNil(unsubErr, "unsubscribe decode error")
		local unsubResponse = router:dispatch(unsubDecoded)

		assertNotNil(unsubResponse, "unsubscribe response")
		assertEqual(unsubResponse.type, "unsubscribeResult")
		assertEqual(#activeSubscriptions, 1)

		-- Verify remaining subscription is logPush (not stateChange)
		local found = false
		for _, sub in activeSubscriptions do
			if sub == "logPush" then
				found = true
			end
			assertTrue(sub ~= "stateChange", "stateChange should be removed")
		end
		assertTrue(found, "logPush should still be subscribed")
	end,
})

return tests
