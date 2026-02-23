--[[
	Tests for Protocol.encode / Protocol.decode.

	Covers round-trip for every message type, error cases, and optional field handling.
]]

local Protocol = require("../src/Shared/Protocol")

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
		error(
			string.format(
				"%sexpected nil, got %s",
				if label then label .. ": " else "",
				tostring(value)
			)
		)
	end
end

local function assertNotNil(value: any, label: string?)
	if value == nil then
		error(
			string.format(
				"%sexpected non-nil value",
				if label then label .. ": " else ""
			)
		)
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
-- Round-trip helper
-- ---------------------------------------------------------------------------

local function roundTrip(message: { [string]: any }): { [string]: any }
	local encoded = Protocol.encode(message :: any)
	local decoded, err = Protocol.decode(encoded)
	if decoded == nil then
		error("round-trip decode failed: " .. tostring(err))
	end
	return decoded :: any
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

local tests = {}

-- 1. Round-trip: hello
table.insert(tests, {
	name = "round-trip hello",
	fn = function()
		local msg = {
			type = "hello",
			sessionId = "sess-001",
			payload = { sessionId = "sess-001" },
		}
		local result = roundTrip(msg)
		assertEqual(result.type, "hello")
		assertEqual(result.sessionId, "sess-001")
		assertEqual(result.payload.sessionId, "sess-001")
	end,
})

-- 2. Round-trip: output
table.insert(tests, {
	name = "round-trip output",
	fn = function()
		local msg = {
			type = "output",
			sessionId = "sess-002",
			payload = {
				messages = {
					{ level = "Print", body = "hello world" },
					{ level = "Warning", body = "be careful" },
				},
			},
		}
		local result = roundTrip(msg)
		assertEqual(result.type, "output")
		assertEqual(#result.payload.messages, 2)
		assertEqual(result.payload.messages[1].level, "Print")
		assertEqual(result.payload.messages[1].body, "hello world")
	end,
})

-- 3. Round-trip: scriptComplete
table.insert(tests, {
	name = "round-trip scriptComplete",
	fn = function()
		local msg = {
			type = "scriptComplete",
			sessionId = "sess-003",
			payload = { success = true },
		}
		local result = roundTrip(msg)
		assertEqual(result.type, "scriptComplete")
		assertEqual(result.payload.success, true)
	end,
})

-- 4. Round-trip: register
table.insert(tests, {
	name = "round-trip register",
	fn = function()
		local msg = {
			type = "register",
			sessionId = "sess-004",
			protocolVersion = 2,
			payload = {
				pluginVersion = "1.0.0",
				instanceId = "inst-xyz",
				context = "edit",
				placeName = "TestPlace",
				placeId = 123,
				gameId = 456,
				state = "Edit",
				capabilities = { "execute", "queryState" },
			},
		}
		local result = roundTrip(msg)
		assertEqual(result.type, "register")
		assertEqual(result.protocolVersion, 2)
		assertEqual(result.payload.pluginVersion, "1.0.0")
		assertEqual(result.payload.instanceId, "inst-xyz")
	end,
})

-- 5. Round-trip: welcome
table.insert(tests, {
	name = "round-trip welcome",
	fn = function()
		local msg = {
			type = "welcome",
			sessionId = "sess-005",
			protocolVersion = 2,
			payload = {
				sessionId = "sess-005",
				capabilities = { "execute", "queryState" },
				serverVersion = "0.5.0",
			},
		}
		local result = roundTrip(msg)
		assertEqual(result.type, "welcome")
		assertEqual(result.protocolVersion, 2)
		assertEqual(result.payload.serverVersion, "0.5.0")
	end,
})

-- 6. Round-trip: execute
table.insert(tests, {
	name = "round-trip execute",
	fn = function()
		local msg = {
			type = "execute",
			sessionId = "sess-006",
			requestId = "req-001",
			payload = { script = "print('hi')" },
		}
		local result = roundTrip(msg)
		assertEqual(result.type, "execute")
		assertEqual(result.requestId, "req-001")
		assertEqual(result.payload.script, "print('hi')")
	end,
})

-- 7. Round-trip: shutdown
table.insert(tests, {
	name = "round-trip shutdown",
	fn = function()
		local msg = {
			type = "shutdown",
			sessionId = "sess-007",
			payload = {},
		}
		local result = roundTrip(msg)
		assertEqual(result.type, "shutdown")
		assertEqual(result.sessionId, "sess-007")
	end,
})

-- 8. Round-trip: queryState / stateResult
table.insert(tests, {
	name = "round-trip queryState and stateResult",
	fn = function()
		local query = {
			type = "queryState",
			sessionId = "sess-008",
			requestId = "req-qs",
			payload = {},
		}
		local qResult = roundTrip(query)
		assertEqual(qResult.type, "queryState")
		assertEqual(qResult.requestId, "req-qs")

		local response = {
			type = "stateResult",
			sessionId = "sess-008",
			requestId = "req-qs",
			payload = {
				state = "Edit",
				placeId = 123,
				placeName = "TestPlace",
				gameId = 456,
			},
		}
		local sResult = roundTrip(response)
		assertEqual(sResult.type, "stateResult")
		assertEqual(sResult.payload.state, "Edit")
		assertEqual(sResult.payload.placeId, 123)
	end,
})

-- 9. Round-trip: captureScreenshot / screenshotResult
table.insert(tests, {
	name = "round-trip captureScreenshot and screenshotResult",
	fn = function()
		local capture = {
			type = "captureScreenshot",
			sessionId = "sess-009",
			requestId = "req-cs",
			payload = { format = "png" },
		}
		local cResult = roundTrip(capture)
		assertEqual(cResult.type, "captureScreenshot")

		local response = {
			type = "screenshotResult",
			sessionId = "sess-009",
			requestId = "req-cs",
			payload = {
				data = "iVBORw0KGgo=",
				format = "png",
				width = 1920,
				height = 1080,
			},
		}
		local sResult = roundTrip(response)
		assertEqual(sResult.type, "screenshotResult")
		assertEqual(sResult.payload.width, 1920)
	end,
})

-- 10. Round-trip: queryDataModel / dataModelResult
table.insert(tests, {
	name = "round-trip queryDataModel and dataModelResult",
	fn = function()
		local query = {
			type = "queryDataModel",
			sessionId = "sess-010",
			requestId = "req-dm",
			payload = { path = "game.Workspace", depth = 1 },
		}
		local qResult = roundTrip(query)
		assertEqual(qResult.type, "queryDataModel")
		assertEqual(qResult.payload.path, "game.Workspace")

		local response = {
			type = "dataModelResult",
			sessionId = "sess-010",
			requestId = "req-dm",
			payload = {
				instance = {
					name = "Workspace",
					className = "Workspace",
					path = "game.Workspace",
					properties = {},
					attributes = {},
					childCount = 3,
				},
			},
		}
		local dResult = roundTrip(response)
		assertEqual(dResult.type, "dataModelResult")
		assertEqual(dResult.payload.instance.name, "Workspace")
		assertEqual(dResult.payload.instance.childCount, 3)
	end,
})

-- 11. Round-trip: queryLogs / logsResult
table.insert(tests, {
	name = "round-trip queryLogs and logsResult",
	fn = function()
		local query = {
			type = "queryLogs",
			sessionId = "sess-011",
			requestId = "req-ql",
			payload = { count = 50, direction = "tail" },
		}
		local qResult = roundTrip(query)
		assertEqual(qResult.type, "queryLogs")
		assertEqual(qResult.payload.count, 50)

		local response = {
			type = "logsResult",
			sessionId = "sess-011",
			requestId = "req-ql",
			payload = {
				entries = {
					{ level = "Print", body = "hello", timestamp = 1000 },
				},
				total = 1,
				bufferCapacity = 1000,
			},
		}
		local lResult = roundTrip(response)
		assertEqual(lResult.type, "logsResult")
		assertEqual(lResult.payload.total, 1)
		assertEqual(lResult.payload.entries[1].body, "hello")
	end,
})

-- 12. Round-trip: subscribe / subscribeResult / unsubscribe / unsubscribeResult
table.insert(tests, {
	name = "round-trip subscribe and unsubscribe flows",
	fn = function()
		local sub = {
			type = "subscribe",
			sessionId = "sess-012",
			requestId = "req-sub",
			payload = { events = { "stateChange", "logPush" } },
		}
		local subResult = roundTrip(sub)
		assertEqual(subResult.type, "subscribe")
		assertEqual(#subResult.payload.events, 2)

		local subConfirm = {
			type = "subscribeResult",
			sessionId = "sess-012",
			requestId = "req-sub",
			payload = { events = { "stateChange", "logPush" } },
		}
		local scResult = roundTrip(subConfirm)
		assertEqual(scResult.type, "subscribeResult")

		local unsub = {
			type = "unsubscribe",
			sessionId = "sess-012",
			requestId = "req-unsub",
			payload = { events = { "stateChange" } },
		}
		local unsubResult = roundTrip(unsub)
		assertEqual(unsubResult.type, "unsubscribe")

		local unsubConfirm = {
			type = "unsubscribeResult",
			sessionId = "sess-012",
			requestId = "req-unsub",
			payload = { events = { "stateChange" } },
		}
		local ucResult = roundTrip(unsubConfirm)
		assertEqual(ucResult.type, "unsubscribeResult")
	end,
})

-- 13. Round-trip: stateChange (push message, no requestId)
table.insert(tests, {
	name = "round-trip stateChange push",
	fn = function()
		local msg = {
			type = "stateChange",
			sessionId = "sess-013",
			payload = {
				previousState = "Edit",
				newState = "Play",
				timestamp = 47230,
			},
		}
		local result = roundTrip(msg)
		assertEqual(result.type, "stateChange")
		assertEqual(result.payload.previousState, "Edit")
		assertEqual(result.payload.newState, "Play")
		assertNil(result.requestId)
	end,
})

-- 14. Round-trip: heartbeat
table.insert(tests, {
	name = "round-trip heartbeat",
	fn = function()
		local msg = {
			type = "heartbeat",
			sessionId = "sess-014",
			payload = {
				uptimeMs = 45000,
				state = "Edit",
				pendingRequests = 0,
			},
		}
		local result = roundTrip(msg)
		assertEqual(result.type, "heartbeat")
		assertEqual(result.payload.uptimeMs, 45000)
		assertEqual(result.payload.pendingRequests, 0)
		assertNil(result.requestId)
	end,
})

-- 15. Round-trip: error (bidirectional)
table.insert(tests, {
	name = "round-trip error message",
	fn = function()
		local msg = {
			type = "error",
			sessionId = "sess-015",
			requestId = "req-err",
			payload = {
				code = "INSTANCE_NOT_FOUND",
				message = "No instance found at path: game.Workspace.NonExistent",
				details = { resolvedTo = "game.Workspace", failedSegment = "NonExistent" },
			},
		}
		local result = roundTrip(msg)
		assertEqual(result.type, "error")
		assertEqual(result.requestId, "req-err")
		assertEqual(result.payload.code, "INSTANCE_NOT_FOUND")
		assertEqual(result.payload.details.failedSegment, "NonExistent")
	end,
})

-- 16. Error case: invalid JSON
table.insert(tests, {
	name = "decode rejects invalid JSON",
	fn = function()
		local result, err = Protocol.decode("not valid json {{{")
		assertNil(result, "result")
		assertNotNil(err, "error")
		assertContains(err :: string, "invalid JSON")
	end,
})

-- 17. Error case: unknown message type
table.insert(tests, {
	name = "decode rejects unknown message type",
	fn = function()
		local json = '{"type":"unknownType","sessionId":"x","payload":{}}'
		local result, err = Protocol.decode(json)
		assertNil(result, "result")
		assertNotNil(err, "error")
		assertContains(err :: string, "unknown message type")
		assertContains(err :: string, "unknownType")
	end,
})

-- 18. Error case: missing sessionId
table.insert(tests, {
	name = "decode rejects missing sessionId",
	fn = function()
		local json = '{"type":"hello","payload":{}}'
		local result, err = Protocol.decode(json)
		assertNil(result, "result")
		assertNotNil(err, "error")
		assertContains(err :: string, "sessionId")
	end,
})

-- 19. Error case: missing payload
table.insert(tests, {
	name = "decode rejects missing payload",
	fn = function()
		local json = '{"type":"hello","sessionId":"x"}'
		local result, err = Protocol.decode(json)
		assertNil(result, "result")
		assertNotNil(err, "error")
		assertContains(err :: string, "payload")
	end,
})

-- 20. Error case: missing type
table.insert(tests, {
	name = "decode rejects missing type",
	fn = function()
		local json = '{"sessionId":"x","payload":{}}'
		local result, err = Protocol.decode(json)
		assertNil(result, "result")
		assertNotNil(err, "error")
		assertContains(err :: string, "type")
	end,
})

-- 21. requestId preserved when present, absent when nil
table.insert(tests, {
	name = "requestId preserved when present, absent when nil",
	fn = function()
		-- With requestId
		local withId = {
			type = "execute",
			sessionId = "sess-rid",
			requestId = "req-123",
			payload = { script = "x" },
		}
		local result1 = roundTrip(withId)
		assertEqual(result1.requestId, "req-123")

		-- Without requestId
		local withoutId = {
			type = "execute",
			sessionId = "sess-rid",
			payload = { script = "x" },
		}
		local result2 = roundTrip(withoutId)
		assertNil(result2.requestId)
	end,
})

-- 22. protocolVersion preserved when present, absent when nil
table.insert(tests, {
	name = "protocolVersion preserved when present, absent when nil",
	fn = function()
		-- With protocolVersion
		local withVer = {
			type = "hello",
			sessionId = "sess-pv",
			protocolVersion = 2,
			payload = { sessionId = "sess-pv" },
		}
		local result1 = roundTrip(withVer)
		assertEqual(result1.protocolVersion, 2)

		-- Without protocolVersion
		local withoutVer = {
			type = "hello",
			sessionId = "sess-pv",
			payload = { sessionId = "sess-pv" },
		}
		local result2 = roundTrip(withoutVer)
		assertNil(result2.protocolVersion)
	end,
})

-- 23. Encode omits nil optional fields from JSON output
table.insert(tests, {
	name = "encode omits nil requestId and protocolVersion",
	fn = function()
		local msg = {
			type = "hello",
			sessionId = "sess-omit",
			payload = { sessionId = "sess-omit" },
		}
		local json = Protocol.encode(msg :: any)
		-- The JSON string should not contain requestId or protocolVersion
		if string.find(json, "requestId", 1, true) then
			error("JSON should not contain requestId when nil")
		end
		if string.find(json, "protocolVersion", 1, true) then
			error("JSON should not contain protocolVersion when nil")
		end
	end,
})

-- 24. Decode handles non-object JSON (e.g., array, string, number)
table.insert(tests, {
	name = "decode rejects non-object JSON values",
	fn = function()
		-- JSON array
		local r1, e1 = Protocol.decode("[1,2,3]")
		-- serde.decode("[1,2,3]") returns a table, but it won't have type/sessionId/payload
		-- so it should fail on the "type" check
		assertNil(r1, "array result")
		assertNotNil(e1, "array error")

		-- JSON string
		local r2, e2 = Protocol.decode('"hello"')
		assertNil(r2, "string result")
		assertNotNil(e2, "string error")

		-- JSON number
		local r3, e3 = Protocol.decode("42")
		assertNil(r3, "number result")
		assertNotNil(e3, "number error")
	end,
})

return tests
