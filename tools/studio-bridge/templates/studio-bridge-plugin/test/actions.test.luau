--[[
	Tests for ActionRouter and MessageBuffer.

	ActionRouter: dispatch, error handling, response type mapping, handler registration.
	MessageBuffer: ring buffer behavior, push, get, clear, capacity overflow.
]]

local ActionRouter = require("../src/Shared/ActionRouter")
local MessageBuffer = require("../src/Shared/MessageBuffer")

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
-- ActionRouter Tests
-- ===========================================================================

-- 1. Register handler, dispatch matching message, response returned
table.insert(tests, {
	name = "ActionRouter: register and dispatch returns handler result",
	fn = function()
		local router = ActionRouter.new()
		router:register("queryState", function(payload, requestId, sessionId)
			return { state = "Edit", placeId = 123, placeName = "TestPlace", gameId = 456 }
		end)

		local response = router:dispatch({
			type = "queryState",
			sessionId = "sess-001",
			requestId = "req-001",
			payload = {},
		})

		assertNotNil(response, "response")
		assertEqual(response.type, "stateResult")
		assertEqual(response.sessionId, "sess-001")
		assertEqual(response.requestId, "req-001")
		assertEqual(response.payload.state, "Edit")
		assertEqual(response.payload.placeId, 123)
	end,
})

-- 2. Dispatch unknown message type returns UNKNOWN_REQUEST error
table.insert(tests, {
	name = "ActionRouter: unknown message type returns UNKNOWN_REQUEST error",
	fn = function()
		local router = ActionRouter.new()

		local response = router:dispatch({
			type = "nonExistentAction",
			sessionId = "sess-002",
			requestId = "req-002",
			payload = {},
		})

		assertNotNil(response, "response")
		assertEqual(response.type, "error")
		assertEqual(response.payload.code, "UNKNOWN_REQUEST")
		assertContains(response.payload.message, "nonExistentAction")
		assertEqual(response.sessionId, "sess-002")
		assertEqual(response.requestId, "req-002")
	end,
})

-- 3. Handler that errors returns INTERNAL_ERROR
table.insert(tests, {
	name = "ActionRouter: handler error returns INTERNAL_ERROR",
	fn = function()
		local router = ActionRouter.new()
		router:register("queryState", function(_payload, _requestId, _sessionId)
			error("something went wrong")
		end)

		local response = router:dispatch({
			type = "queryState",
			sessionId = "sess-003",
			requestId = "req-003",
			payload = {},
		})

		assertNotNil(response, "response")
		assertEqual(response.type, "error")
		assertEqual(response.payload.code, "INTERNAL_ERROR")
		assertContains(response.payload.message, "something went wrong")
	end,
})

-- 4. Response has correct response type (e.g. queryState -> stateResult)
table.insert(tests, {
	name = "ActionRouter: response type mapping is correct for each action",
	fn = function()
		local router = ActionRouter.new()
		local typeMap = {
			{ input = "execute", expected = "scriptComplete" },
			{ input = "queryState", expected = "stateResult" },
			{ input = "captureScreenshot", expected = "screenshotResult" },
			{ input = "queryDataModel", expected = "dataModelResult" },
			{ input = "queryLogs", expected = "logsResult" },
			{ input = "subscribe", expected = "subscribeResult" },
			{ input = "unsubscribe", expected = "unsubscribeResult" },
		}

		for _, mapping in typeMap do
			router:register(mapping.input, function()
				return { ok = true }
			end)
		end

		for _, mapping in typeMap do
			local response = router:dispatch({
				type = mapping.input,
				sessionId = "sess-type",
				requestId = "req-type",
				payload = {},
			})
			assertNotNil(response, mapping.input .. " response")
			assertEqual(response.type, mapping.expected, mapping.input .. " -> " .. mapping.expected)
		end
	end,
})

-- 5. Response preserves sessionId and requestId
table.insert(tests, {
	name = "ActionRouter: response preserves sessionId and requestId",
	fn = function()
		local router = ActionRouter.new()
		router:register("queryLogs", function()
			return { entries = {}, total = 0, bufferCapacity = 1000 }
		end)

		local response = router:dispatch({
			type = "queryLogs",
			sessionId = "my-session-xyz",
			requestId = "my-request-abc",
			payload = {},
		})

		assertNotNil(response)
		assertEqual(response.sessionId, "my-session-xyz")
		assertEqual(response.requestId, "my-request-abc")
	end,
})

-- 6. Handler returning nil generates no response
table.insert(tests, {
	name = "ActionRouter: handler returning nil generates no response",
	fn = function()
		local router = ActionRouter.new()
		router:register("execute", function()
			return nil
		end)

		local response = router:dispatch({
			type = "execute",
			sessionId = "sess-nil",
			requestId = "req-nil",
			payload = { script = "print('hi')" },
		})

		assertNil(response, "response should be nil")
	end,
})

-- 7. Multiple handlers for different types
table.insert(tests, {
	name = "ActionRouter: multiple handlers for different types work independently",
	fn = function()
		local router = ActionRouter.new()
		local stateCallCount = 0
		local logsCallCount = 0

		router:register("queryState", function()
			stateCallCount = stateCallCount + 1
			return { state = "Edit" }
		end)

		router:register("queryLogs", function()
			logsCallCount = logsCallCount + 1
			return { entries = {}, total = 0, bufferCapacity = 1000 }
		end)

		router:dispatch({
			type = "queryState",
			sessionId = "sess-multi",
			requestId = "req-1",
			payload = {},
		})

		router:dispatch({
			type = "queryLogs",
			sessionId = "sess-multi",
			requestId = "req-2",
			payload = {},
		})

		router:dispatch({
			type = "queryState",
			sessionId = "sess-multi",
			requestId = "req-3",
			payload = {},
		})

		assertEqual(stateCallCount, 2, "state handler called twice")
		assertEqual(logsCallCount, 1, "logs handler called once")
	end,
})

-- 8. Handler receives correct payload, requestId, sessionId arguments
table.insert(tests, {
	name = "ActionRouter: handler receives correct arguments",
	fn = function()
		local router = ActionRouter.new()
		local receivedPayload, receivedRequestId, receivedSessionId

		router:register("queryDataModel", function(payload, requestId, sessionId)
			receivedPayload = payload
			receivedRequestId = requestId
			receivedSessionId = sessionId
			return { instance = {} }
		end)

		router:dispatch({
			type = "queryDataModel",
			sessionId = "sess-args",
			requestId = "req-args",
			payload = { path = "game.Workspace", depth = 2 },
		})

		assertNotNil(receivedPayload, "payload")
		assertEqual(receivedPayload.path, "game.Workspace")
		assertEqual(receivedPayload.depth, 2)
		assertEqual(receivedRequestId, "req-args")
		assertEqual(receivedSessionId, "sess-args")
	end,
})

-- ===========================================================================
-- MessageBuffer Tests
-- ===========================================================================

-- 9. Push entries, get them back
table.insert(tests, {
	name = "MessageBuffer: push entries and get them back",
	fn = function()
		local buf = MessageBuffer.new(100)
		buf:push({ level = "Print", body = "hello", timestamp = 1000 })
		buf:push({ level = "Warning", body = "careful", timestamp = 2000 })
		buf:push({ level = "Error", body = "oops", timestamp = 3000 })

		local result = buf:get()
		assertEqual(#result.entries, 3)
		assertEqual(result.total, 3)
		assertEqual(result.bufferCapacity, 100)
		assertEqual(result.entries[1].body, "hello")
		assertEqual(result.entries[2].body, "careful")
		assertEqual(result.entries[3].body, "oops")
	end,
})

-- 10. Buffer at capacity overwrites oldest
table.insert(tests, {
	name = "MessageBuffer: at capacity overwrites oldest entries",
	fn = function()
		local buf = MessageBuffer.new(3)
		buf:push({ level = "Print", body = "a", timestamp = 1 })
		buf:push({ level = "Print", body = "b", timestamp = 2 })
		buf:push({ level = "Print", body = "c", timestamp = 3 })
		-- Buffer full: [a, b, c]
		buf:push({ level = "Print", body = "d", timestamp = 4 })
		-- Now oldest (a) overwritten: [d, b, c] but chronologically: b, c, d

		assertEqual(buf:size(), 3, "size stays at capacity")
		local result = buf:get()
		assertEqual(#result.entries, 3)
		assertEqual(result.entries[1].body, "b", "oldest remaining")
		assertEqual(result.entries[2].body, "c")
		assertEqual(result.entries[3].body, "d", "newest")
	end,
})

-- 11. get("tail", 5) returns 5 most recent
table.insert(tests, {
	name = 'MessageBuffer: get("tail", 5) returns 5 most recent',
	fn = function()
		local buf = MessageBuffer.new(100)
		for i = 1, 20 do
			buf:push({ level = "Print", body = "msg-" .. tostring(i), timestamp = i * 100 })
		end

		local result = buf:get("tail", 5)
		assertEqual(#result.entries, 5)
		assertEqual(result.entries[1].body, "msg-16")
		assertEqual(result.entries[2].body, "msg-17")
		assertEqual(result.entries[3].body, "msg-18")
		assertEqual(result.entries[4].body, "msg-19")
		assertEqual(result.entries[5].body, "msg-20")
		assertEqual(result.total, 20)
	end,
})

-- 12. get("head", 5) returns 5 oldest
table.insert(tests, {
	name = 'MessageBuffer: get("head", 5) returns 5 oldest',
	fn = function()
		local buf = MessageBuffer.new(100)
		for i = 1, 20 do
			buf:push({ level = "Print", body = "msg-" .. tostring(i), timestamp = i * 100 })
		end

		local result = buf:get("head", 5)
		assertEqual(#result.entries, 5)
		assertEqual(result.entries[1].body, "msg-1")
		assertEqual(result.entries[2].body, "msg-2")
		assertEqual(result.entries[3].body, "msg-3")
		assertEqual(result.entries[4].body, "msg-4")
		assertEqual(result.entries[5].body, "msg-5")
	end,
})

-- 13. clear() empties buffer
table.insert(tests, {
	name = "MessageBuffer: clear() empties the buffer",
	fn = function()
		local buf = MessageBuffer.new(100)
		buf:push({ level = "Print", body = "a", timestamp = 1 })
		buf:push({ level = "Print", body = "b", timestamp = 2 })
		assertEqual(buf:size(), 2)

		buf:clear()
		assertEqual(buf:size(), 0)

		local result = buf:get()
		assertEqual(#result.entries, 0)
		assertEqual(result.total, 0)
	end,
})

-- 14. size() returns correct count
table.insert(tests, {
	name = "MessageBuffer: size() returns correct count",
	fn = function()
		local buf = MessageBuffer.new(5)
		assertEqual(buf:size(), 0)

		buf:push({ level = "Print", body = "a", timestamp = 1 })
		assertEqual(buf:size(), 1)

		buf:push({ level = "Print", body = "b", timestamp = 2 })
		assertEqual(buf:size(), 2)

		-- Fill to capacity
		buf:push({ level = "Print", body = "c", timestamp = 3 })
		buf:push({ level = "Print", body = "d", timestamp = 4 })
		buf:push({ level = "Print", body = "e", timestamp = 5 })
		assertEqual(buf:size(), 5)

		-- Overflow
		buf:push({ level = "Print", body = "f", timestamp = 6 })
		assertEqual(buf:size(), 5, "size stays at capacity after overflow")
	end,
})

-- 15. Default direction is "tail"
table.insert(tests, {
	name = 'MessageBuffer: default direction is "tail"',
	fn = function()
		local buf = MessageBuffer.new(100)
		for i = 1, 10 do
			buf:push({ level = "Print", body = "msg-" .. tostring(i), timestamp = i * 100 })
		end

		-- get() with no args should behave like get("tail")
		local defaultResult = buf:get()
		local tailResult = buf:get("tail")

		assertEqual(#defaultResult.entries, #tailResult.entries)
		for i = 1, #defaultResult.entries do
			assertEqual(defaultResult.entries[i].body, tailResult.entries[i].body)
		end
	end,
})

-- 16. Count larger than buffer size returns all entries
table.insert(tests, {
	name = "MessageBuffer: count larger than buffer size returns all entries",
	fn = function()
		local buf = MessageBuffer.new(100)
		buf:push({ level = "Print", body = "a", timestamp = 1 })
		buf:push({ level = "Print", body = "b", timestamp = 2 })
		buf:push({ level = "Print", body = "c", timestamp = 3 })

		local resultTail = buf:get("tail", 100)
		assertEqual(#resultTail.entries, 3, "tail count > size returns all")

		local resultHead = buf:get("head", 100)
		assertEqual(#resultHead.entries, 3, "head count > size returns all")
	end,
})

-- 17. Ring buffer maintains correct order after multiple wraps
table.insert(tests, {
	name = "MessageBuffer: correct order after multiple wraps around capacity",
	fn = function()
		local buf = MessageBuffer.new(3)
		-- Fill and overflow multiple times
		for i = 1, 10 do
			buf:push({ level = "Print", body = "msg-" .. tostring(i), timestamp = i * 100 })
		end

		-- Should contain the last 3: msg-8, msg-9, msg-10
		local result = buf:get()
		assertEqual(#result.entries, 3)
		assertEqual(result.entries[1].body, "msg-8")
		assertEqual(result.entries[2].body, "msg-9")
		assertEqual(result.entries[3].body, "msg-10")
	end,
})

-- 18. MessageBuffer default capacity is 1000
table.insert(tests, {
	name = "MessageBuffer: default capacity is 1000",
	fn = function()
		local buf = MessageBuffer.new()
		local result = buf:get()
		assertEqual(result.bufferCapacity, 1000)
	end,
})

-- 19. get preserves entry fields correctly
table.insert(tests, {
	name = "MessageBuffer: get preserves entry fields (level, body, timestamp)",
	fn = function()
		local buf = MessageBuffer.new(10)
		buf:push({ level = "Warning", body = "be careful", timestamp = 42000 })

		local result = buf:get()
		assertEqual(#result.entries, 1)
		assertEqual(result.entries[1].level, "Warning")
		assertEqual(result.entries[1].body, "be careful")
		assertEqual(result.entries[1].timestamp, 42000)
	end,
})

-- 20. ActionRouter: dispatch with nil requestId
table.insert(tests, {
	name = "ActionRouter: dispatch with nil requestId still works",
	fn = function()
		local router = ActionRouter.new()
		router:register("execute", function(payload, requestId, sessionId)
			return { success = true }
		end)

		local response = router:dispatch({
			type = "execute",
			sessionId = "sess-no-rid",
			payload = { script = "print('hi')" },
		})

		assertNotNil(response)
		assertEqual(response.type, "scriptComplete")
		assertEqual(response.sessionId, "sess-no-rid")
		-- requestId should be nil since we didn't provide one
		assertNil(response.requestId, "requestId should be nil")
		assertEqual(response.payload.success, true)
	end,
})

-- 21. MessageBuffer: head and tail on overflow buffer
table.insert(tests, {
	name = "MessageBuffer: head and tail on overflow buffer return correct slices",
	fn = function()
		local buf = MessageBuffer.new(5)
		for i = 1, 8 do
			buf:push({ level = "Print", body = "m" .. tostring(i), timestamp = i })
		end
		-- Buffer contains: m4, m5, m6, m7, m8

		local head2 = buf:get("head", 2)
		assertEqual(#head2.entries, 2)
		assertEqual(head2.entries[1].body, "m4")
		assertEqual(head2.entries[2].body, "m5")

		local tail2 = buf:get("tail", 2)
		assertEqual(#tail2.entries, 2)
		assertEqual(tail2.entries[1].body, "m7")
		assertEqual(tail2.entries[2].body, "m8")
	end,
})

-- 22. ActionRouter: UNKNOWN_REQUEST for dispatch without any handlers
table.insert(tests, {
	name = "ActionRouter: UNKNOWN_REQUEST when no handlers registered",
	fn = function()
		local router = ActionRouter.new()
		local response = router:dispatch({
			type = "queryState",
			sessionId = "sess-empty",
			requestId = "req-empty",
			payload = {},
		})
		assertNotNil(response)
		assertEqual(response.type, "error")
		assertEqual(response.payload.code, "UNKNOWN_REQUEST")
	end,
})

-- 23. MessageBuffer: push after clear works correctly
table.insert(tests, {
	name = "MessageBuffer: push after clear works correctly",
	fn = function()
		local buf = MessageBuffer.new(5)
		buf:push({ level = "Print", body = "before", timestamp = 1 })
		buf:push({ level = "Print", body = "before2", timestamp = 2 })
		buf:clear()
		assertEqual(buf:size(), 0)

		buf:push({ level = "Print", body = "after", timestamp = 3 })
		assertEqual(buf:size(), 1)
		local result = buf:get()
		assertEqual(#result.entries, 1)
		assertEqual(result.entries[1].body, "after")
	end,
})

return tests
