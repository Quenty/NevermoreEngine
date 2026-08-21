--[[
	Tests for the ExecuteAction handler module.

	Covers:
	  - Script execution returns success
	  - requestId echoed when present
	  - requestId omitted when absent (v1 mode)
	  - loadstring failure returns SCRIPT_LOAD_ERROR
	  - Runtime error returns SCRIPT_RUNTIME_ERROR
	  - Sequential queueing via sendMessage callback
]]

local ActionRouter = require("../../studio-bridge-plugin/src/Shared/ActionRouter")
local ExecuteAction = require("../../../src/commands/console/exec/execute")

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

local function assertNotNil(value: any, label: string?)
	if value == nil then
		error(string.format("%sexpected non-nil value", if label then label .. ": " else ""))
	end
end

local function assertNil(value: any, label: string?)
	if value ~= nil then
		error(string.format("%sexpected nil, got %s", if label then label .. ": " else "", tostring(value)))
	end
end

local function assertTrue(value: any, label: string?)
	if not value then
		error(string.format("%sexpected truthy value, got %s", if label then label .. ": " else "", tostring(value)))
	end
end

local function assertFalse(value: any, label: string?)
	if value then
		error(string.format("%sexpected falsy value, got %s", if label then label .. ": " else "", tostring(value)))
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
-- Direct handleExecute tests
-- ===========================================================================

table.insert(tests, {
	name = "handleExecute: successful execution returns success",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "local x = 1 + 1" }, "req-1", "sess-1")
		assertNotNil(result)
		assertTrue(result.success, "should succeed")
	end,
})

table.insert(tests, {
	name = "handleExecute: loadstring failure returns SCRIPT_LOAD_ERROR",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "local x = (" }, "req-2", "sess-2")
		assertNotNil(result)
		assertFalse(result.success, "should fail")
		assertEqual(result.code, "SCRIPT_LOAD_ERROR", "error code")
		assertNotNil(result.error, "error message should be present")
	end,
})

table.insert(tests, {
	name = "handleExecute: runtime error returns SCRIPT_RUNTIME_ERROR",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "error('boom')" }, "req-3", "sess-3")
		assertNotNil(result)
		assertFalse(result.success, "should fail")
		assertEqual(result.code, "SCRIPT_RUNTIME_ERROR", "error code")
		assertContains(result.error, "boom")
	end,
})

table.insert(tests, {
	name = "handleExecute: missing code returns SCRIPT_LOAD_ERROR",
	fn = function()
		local result = ExecuteAction.handleExecute({}, "req-4", "sess-4")
		assertNotNil(result)
		assertFalse(result.success, "should fail")
		assertEqual(result.code, "SCRIPT_LOAD_ERROR", "error code")
		assertContains(result.error, "Missing code")
	end,
})

table.insert(tests, {
	name = "handleExecute: non-string code returns SCRIPT_LOAD_ERROR",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = 42 }, "req-5", "sess-5")
		assertNotNil(result)
		assertFalse(result.success, "should fail")
		assertEqual(result.code, "SCRIPT_LOAD_ERROR", "error code")
	end,
})

-- ===========================================================================
-- requestId correlation tests
-- ===========================================================================

table.insert(tests, {
	name = "requestId: echoed in scriptComplete when present (via sendMessage)",
	fn = function()
		ExecuteAction._resetQueue()
		local sentMessages = {}
		local sendMessage = function(msg)
			table.insert(sentMessages, msg)
		end

		local router = ActionRouter.new()
		ExecuteAction.register(router, sendMessage)

		router:dispatch({
			type = "execute",
			sessionId = "sess-rid",
			requestId = "req-abc-123",
			payload = { code = "local x = 1" },
		})

		assertEqual(#sentMessages, 1, "one message sent")
		local msg = sentMessages[1]
		assertEqual(msg.type, "scriptComplete")
		assertEqual(msg.sessionId, "sess-rid")
		assertEqual(msg.requestId, "req-abc-123", "requestId should be echoed")
		assertTrue(msg.payload.success)
	end,
})

table.insert(tests, {
	name = "requestId: omitted from scriptComplete when absent (v1 mode)",
	fn = function()
		ExecuteAction._resetQueue()
		local sentMessages = {}
		local sendMessage = function(msg)
			table.insert(sentMessages, msg)
		end

		local router = ActionRouter.new()
		ExecuteAction.register(router, sendMessage)

		-- ActionRouter passes "" when requestId is nil
		router:dispatch({
			type = "execute",
			sessionId = "sess-v1",
			payload = { code = "local x = 1" },
		})

		assertEqual(#sentMessages, 1, "one message sent")
		local msg = sentMessages[1]
		assertEqual(msg.type, "scriptComplete")
		assertEqual(msg.sessionId, "sess-v1")
		assertNil(msg.requestId, "requestId should be omitted in v1 mode")
		assertTrue(msg.payload.success)
	end,
})

table.insert(tests, {
	name = "requestId: echoed in direct mode (no sendMessage) via ActionRouter",
	fn = function()
		local router = ActionRouter.new()
		ExecuteAction.register(router)

		local response = router:dispatch({
			type = "execute",
			sessionId = "sess-direct",
			requestId = "req-direct-123",
			payload = { code = "local x = 42" },
		})

		assertNotNil(response)
		assertEqual(response.type, "scriptComplete")
		assertEqual(response.requestId, "req-direct-123")
		assertTrue(response.payload.success)
	end,
})

-- ===========================================================================
-- Error code tests through ActionRouter
-- ===========================================================================

table.insert(tests, {
	name = "ActionRouter: loadstring failure returns SCRIPT_LOAD_ERROR code",
	fn = function()
		local router = ActionRouter.new()
		ExecuteAction.register(router)

		local response = router:dispatch({
			type = "execute",
			sessionId = "sess-load",
			requestId = "req-load",
			payload = { code = "local x = (" },
		})

		assertNotNil(response)
		assertEqual(response.type, "scriptComplete")
		assertFalse(response.payload.success)
		assertEqual(response.payload.code, "SCRIPT_LOAD_ERROR", "error code")
	end,
})

table.insert(tests, {
	name = "ActionRouter: runtime error returns SCRIPT_RUNTIME_ERROR code",
	fn = function()
		local router = ActionRouter.new()
		ExecuteAction.register(router)

		local response = router:dispatch({
			type = "execute",
			sessionId = "sess-runtime",
			requestId = "req-runtime",
			payload = { code = "error('something went wrong')" },
		})

		assertNotNil(response)
		assertEqual(response.type, "scriptComplete")
		assertFalse(response.payload.success)
		assertEqual(response.payload.code, "SCRIPT_RUNTIME_ERROR", "error code")
		assertContains(response.payload.error, "something went wrong")
	end,
})

-- ===========================================================================
-- Sequential queueing tests
-- ===========================================================================

table.insert(tests, {
	name = "sequential queue: processes multiple requests in order",
	fn = function()
		ExecuteAction._resetQueue()
		local sentMessages = {}
		local sendMessage = function(msg)
			table.insert(sentMessages, msg)
		end

		local router = ActionRouter.new()
		ExecuteAction.register(router, sendMessage)

		-- Dispatch multiple requests
		router:dispatch({
			type = "execute",
			sessionId = "sess-q",
			requestId = "req-q1",
			payload = { code = "local a = 1" },
		})

		router:dispatch({
			type = "execute",
			sessionId = "sess-q",
			requestId = "req-q2",
			payload = { code = "local b = 2" },
		})

		router:dispatch({
			type = "execute",
			sessionId = "sess-q",
			requestId = "req-q3",
			payload = { code = "error('fail')" },
		})

		assertEqual(#sentMessages, 3, "three messages sent")
		assertEqual(sentMessages[1].requestId, "req-q1")
		assertTrue(sentMessages[1].payload.success)
		assertEqual(sentMessages[2].requestId, "req-q2")
		assertTrue(sentMessages[2].payload.success)
		assertEqual(sentMessages[3].requestId, "req-q3")
		assertFalse(sentMessages[3].payload.success)
		assertEqual(sentMessages[3].payload.code, "SCRIPT_RUNTIME_ERROR")
	end,
})

table.insert(tests, {
	name = "sequential queue: error in one request does not block subsequent requests",
	fn = function()
		ExecuteAction._resetQueue()
		local sentMessages = {}
		local sendMessage = function(msg)
			table.insert(sentMessages, msg)
		end

		local router = ActionRouter.new()
		ExecuteAction.register(router, sendMessage)

		-- First request: compile error
		router:dispatch({
			type = "execute",
			sessionId = "sess-err-q",
			requestId = "req-err1",
			payload = { code = "local x = (" },
		})

		-- Second request: success
		router:dispatch({
			type = "execute",
			sessionId = "sess-err-q",
			requestId = "req-ok1",
			payload = { code = "local y = 42" },
		})

		assertEqual(#sentMessages, 2, "two messages sent")
		assertFalse(sentMessages[1].payload.success)
		assertEqual(sentMessages[1].payload.code, "SCRIPT_LOAD_ERROR")
		assertTrue(sentMessages[2].payload.success)
	end,
})

table.insert(tests, {
	name = "sequential queue: a request that throws while reporting is answered, not latched",
	fn = function()
		ExecuteAction._resetQueue()
		local sentMessages = {}
		local failNextSend = true
		local sendMessage = function(msg)
			if failNextSend then
				failNextSend = false
				error("encode failed")
			end
			table.insert(sentMessages, msg)
		end

		local router = ActionRouter.new()
		ExecuteAction.register(router, sendMessage)

		router:dispatch({
			type = "execute",
			sessionId = "sess-wedge",
			requestId = "req-w1",
			payload = { code = "return 1" },
		})

		assertEqual(#sentMessages, 1, "the failed request is reported rather than dropped")
		assertEqual(sentMessages[1].requestId, "req-w1")
		assertFalse(sentMessages[1].payload.success)
		assertEqual(sentMessages[1].payload.code, "INTERNAL_ERROR")

		-- The queue must still drain: a latched _processing would leave this
		-- request, and every later one, sitting in the queue forever.
		router:dispatch({
			type = "execute",
			sessionId = "sess-wedge",
			requestId = "req-w2",
			payload = { code = "print('innocent'); return 2" },
		})

		assertEqual(#sentMessages, 2, "the next request still runs")
		assertEqual(sentMessages[2].requestId, "req-w2")
		assertTrue(sentMessages[2].payload.success)
		assertEqual(sentMessages[2].payload.returnValues[1], 2)
	end,
})

table.insert(tests, {
	name = "sequential queue: drains even when the failure itself cannot be reported",
	fn = function()
		ExecuteAction._resetQueue()

		local deadRouter = ActionRouter.new()
		ExecuteAction.register(deadRouter, function()
			error("encode failed")
		end)

		deadRouter:dispatch({
			type = "execute",
			sessionId = "sess-wedge2",
			requestId = "req-w3",
			payload = { code = "return 1" },
		})

		-- Nothing could be delivered for req-w3, so the only observable question
		-- is whether the queue was released for whoever comes next.
		local sentMessages = {}
		local liveRouter = ActionRouter.new()
		ExecuteAction.register(liveRouter, function(msg)
			table.insert(sentMessages, msg)
		end)

		liveRouter:dispatch({
			type = "execute",
			sessionId = "sess-wedge2",
			requestId = "req-w4",
			payload = { code = "return 4" },
		})

		assertEqual(#sentMessages, 1, "a later request still gets a response")
		assertEqual(sentMessages[1].requestId, "req-w4")
		assertTrue(sentMessages[1].payload.success)
	end,
})

-- ===========================================================================
-- sendMessage callback integration
-- ===========================================================================

table.insert(tests, {
	name = "sendMessage: sends scriptComplete with correct structure",
	fn = function()
		ExecuteAction._resetQueue()
		local sentMessages = {}
		local sendMessage = function(msg)
			table.insert(sentMessages, msg)
		end

		local router = ActionRouter.new()
		ExecuteAction.register(router, sendMessage)

		-- ActionRouter should return nil (handler sends messages directly)
		local routerResponse = router:dispatch({
			type = "execute",
			sessionId = "sess-send",
			requestId = "req-send",
			payload = { code = "local x = 1" },
		})

		-- Router should not generate a response (handler returned nil)
		assertNil(routerResponse, "router should not generate a response")

		-- But the message was sent via sendMessage
		assertEqual(#sentMessages, 1, "one message sent via sendMessage")
		local msg = sentMessages[1]
		assertEqual(msg.type, "scriptComplete")
		assertEqual(msg.sessionId, "sess-send")
		assertEqual(msg.requestId, "req-send")
		assertTrue(msg.payload.success)
	end,
})

table.insert(tests, {
	name = "sendMessage: error response includes code and error message",
	fn = function()
		ExecuteAction._resetQueue()
		local sentMessages = {}
		local sendMessage = function(msg)
			table.insert(sentMessages, msg)
		end

		local router = ActionRouter.new()
		ExecuteAction.register(router, sendMessage)

		router:dispatch({
			type = "execute",
			sessionId = "sess-senderr",
			requestId = "req-senderr",
			payload = { code = "error('kaboom')" },
		})

		assertEqual(#sentMessages, 1, "one message sent")
		local msg = sentMessages[1]
		assertEqual(msg.type, "scriptComplete")
		assertFalse(msg.payload.success)
		assertEqual(msg.payload.code, "SCRIPT_RUNTIME_ERROR")
		assertContains(msg.payload.error, "kaboom")
	end,
})

-- ===========================================================================
-- Return value marshalling
-- ===========================================================================

table.insert(tests, {
	name = "returnValues: empty when the script returns nothing",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "local x = 1" }, "req-rv0", "sess-rv0")
		assertNotNil(result.returnValues, "returnValues should be present on a successful run")
		assertEqual(#result.returnValues, 0, "no values returned")
	end,
})

table.insert(tests, {
	name = "returnValues: carries every returned value in order",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "return 'str', 42, true" }, "req-rv1", "sess-rv1")
		assertEqual(#result.returnValues, 3, "three values returned")
		assertEqual(result.returnValues[1], "str")
		assertEqual(result.returnValues[2], 42)
		assertEqual(result.returnValues[3], true)
	end,
})

table.insert(tests, {
	name = "returnValues: nested tables survive as tables",
	fn = function()
		local result = ExecuteAction.handleExecute(
			{ code = "return { slug = 'maid', counts = { passed = 1014, failed = 0 } }" },
			"req-rv2",
			"sess-rv2"
		)
		assertEqual(#result.returnValues, 1, "one value returned")
		local value = result.returnValues[1]
		assertEqual(value.slug, "maid")
		assertEqual(value.counts.passed, 1014)
		assertEqual(value.counts.failed, 0)
	end,
})

table.insert(tests, {
	name = "returnValues: array-like tables stay arrays",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "return { 10, 20, 30 }" }, "req-rv3", "sess-rv3")
		local value = result.returnValues[1]
		assertEqual(#value, 3, "array length")
		assertEqual(value[1], 10)
		assertEqual(value[3], 30)
	end,
})

table.insert(tests, {
	name = "returnValues: non-string keys become strings so the table can be encoded",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "return { [1] = 'a', name = 'b' }" }, "req-rv4", "sess-rv4")
		local value = result.returnValues[1]
		assertEqual(value["1"], "a", "numeric key stringified")
		assertEqual(value.name, "b")
	end,
})

table.insert(tests, {
	name = "returnValues: a returned nil keeps its position",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "return nil, 7" }, "req-rv5", "sess-rv5")
		assertEqual(#result.returnValues, 2, "two values returned")
		assertEqual(result.returnValues[1].type, "Nil", "nil marker")
		assertEqual(result.returnValues[2], 7)
	end,
})

table.insert(tests, {
	name = "returnValues: a cycle is reported instead of recursing forever",
	fn = function()
		local result =
			ExecuteAction.handleExecute({ code = "local t = {}; t.self = t; return t" }, "req-rv6", "sess-rv6")
		local value = result.returnValues[1]
		assertEqual(value.self.type, "Unsupported", "cycle is marked unsupported")
		assertContains(value.self.toString, "cycle")
	end,
})

table.insert(tests, {
	name = "returnValues: non-finite numbers are marked, not emitted as invalid JSON",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "return math.huge, 0 / 0" }, "req-rv7", "sess-rv7")
		assertEqual(result.returnValues[1].type, "Unsupported", "inf is marked")
		assertEqual(result.returnValues[1].typeName, "number")
		assertEqual(result.returnValues[2].type, "Unsupported", "nan is marked")
	end,
})

table.insert(tests, {
	name = "returnValues: functions are marked unsupported rather than dropped",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "return function() end" }, "req-rv8", "sess-rv8")
		assertEqual(#result.returnValues, 1, "one value returned")
		assertEqual(result.returnValues[1].type, "Unsupported")
		assertEqual(result.returnValues[1].typeName, "function")
	end,
})

table.insert(tests, {
	name = "returnValues: a hostile key metamethod degrades to a marker instead of throwing",
	fn = function()
		local result = ExecuteAction.handleExecute({
			code = "local k = setmetatable({}, { __tostring = function() error('bad tostring') end }); return { [k] = 1, name = 2 }",
		}, "req-rv10", "sess-rv10")
		assertTrue(result.success, "the run itself still succeeded")
		assertEqual(#result.returnValues, 1, "one marker in place of the values")
		assertEqual(result.returnValues[1].type, "Unsupported")
		assertContains(result.returnValues[1].toString, "not serializable")
	end,
})

table.insert(tests, {
	name = "returnValues: __iter is bypassed, so real contents are marshalled",
	fn = function()
		local result = ExecuteAction.handleExecute({
			code = "return setmetatable({ real = 'x' }, { __iter = function() error('bad iter') end })",
		}, "req-rv11", "sess-rv11")
		assertTrue(result.success, "should succeed")
		assertEqual(result.returnValues[1].real, "x", "raw contents, not whatever __iter yields")
	end,
})

table.insert(tests, {
	name = "returnValues: shared references cannot explode past the node budget",
	fn = function()
		-- Only 30 levels deep, but 2^30 nodes if every shared edge is expanded.
		local result = ExecuteAction.handleExecute(
			{ code = "local x = {}; for _ = 1, 30 do x = { a = x, b = x } end; return x" },
			"req-rv12",
			"sess-rv12"
		)
		assertTrue(result.success, "should succeed")

		local function findBudgetMarker(value: any): boolean
			if type(value) ~= "table" then
				return false
			end
			if value.type == "Unsupported" and string.find(tostring(value.toString), "budget", 1, true) then
				return true
			end
			for _, item in value do
				if findBudgetMarker(item) then
					return true
				end
			end
			return false
		end

		assertTrue(findBudgetMarker(result.returnValues[1]), "walk stopped at the budget")
	end,
})

table.insert(tests, {
	name = "returnValues: keys that collapse onto one JSON key are marked, not silently dropped",
	fn = function()
		local result =
			ExecuteAction.handleExecute({ code = "return { [1] = 'a', ['1'] = 'b' }" }, "req-rv13", "sess-rv13")
		local value = result.returnValues[1]
		assertEqual(value["1"].type, "Unsupported", "collision is marked")
		assertEqual(value["1"].typeName, "collision")
	end,
})

table.insert(tests, {
	name = "returnValues: absent on a failed run",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "error('boom')" }, "req-rv9", "sess-rv9")
		assertFalse(result.success)
		assertNil(result.returnValues, "a failed run reports no return values")
	end,
})

return tests
