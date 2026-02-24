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
local ExecuteAction = require("../../studio-bridge-plugin/src/Actions/ExecuteAction")

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
		error(
			string.format(
				"%sexpected non-nil value",
				if label then label .. ": " else ""
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

local function assertFalse(value: any, label: string?)
	if value then
		error(
			string.format(
				"%sexpected falsy value, got %s",
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

return tests
