--[[
	Tests for new action handlers: execute field fix, QueryLogsAction,
	CaptureScreenshotAction stub, and SubscribeAction stubs.

	QueryStateAction requires Roblox services (RunService, game) and
	cannot be tested under Lune. It is tested manually via
	`studio-bridge state` after installation.
]]

local ActionRouter = require("../../studio-bridge-plugin/src/Shared/ActionRouter")
local MessageBuffer = require("../../studio-bridge-plugin/src/Shared/MessageBuffer")
local ExecuteAction = require("../../studio-bridge-plugin/src/Actions/ExecuteAction")
local QueryLogsAction = require("../../studio-bridge-plugin/src/Actions/QueryLogsAction")
local CaptureScreenshotAction = require("../../studio-bridge-plugin/src/Actions/CaptureScreenshotAction")
local SubscribeAction = require("../../studio-bridge-plugin/src/Actions/SubscribeAction")

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

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

local tests = {}

-- ===========================================================================
-- Execute field name fix
-- ===========================================================================

table.insert(tests, {
	name = "ExecuteAction: payload.script is accepted (protocol spec field name)",
	fn = function()
		ExecuteAction._resetQueue()
		local result = ExecuteAction.handleExecute({ script = "local x = 1 + 1" }, "req-1", "sess-1")
		assertNotNil(result)
		assertTrue(result.success, "should succeed with payload.script")
	end,
})

table.insert(tests, {
	name = "ExecuteAction: payload.code still works (backward compat)",
	fn = function()
		ExecuteAction._resetQueue()
		local result = ExecuteAction.handleExecute({ code = "local x = 2 + 2" }, "req-2", "sess-2")
		assertNotNil(result)
		assertTrue(result.success, "should succeed with payload.code")
	end,
})

table.insert(tests, {
	name = "ExecuteAction: payload.script takes precedence over payload.code",
	fn = function()
		ExecuteAction._resetQueue()
		-- script is valid, code would fail
		local result = ExecuteAction.handleExecute({
			script = "local x = 1",
			code = "this is not valid luau ~~~",
		}, "req-3", "sess-3")
		assertNotNil(result)
		assertTrue(result.success, "payload.script should take precedence")
	end,
})

table.insert(tests, {
	name = "ExecuteAction: dispatched via ActionRouter with payload.script",
	fn = function()
		ExecuteAction._resetQueue()
		local router = ActionRouter.new()
		ExecuteAction.register(router, nil)

		local response = router:dispatch({
			type = "execute",
			sessionId = "sess-4",
			requestId = "req-4",
			payload = { script = "local x = 42" },
		})

		assertNotNil(response, "should get a response")
		assertEqual(response.type, "scriptComplete")
		assertTrue(response.payload.success, "should succeed")
	end,
})

-- ===========================================================================
-- QueryLogsAction
-- ===========================================================================

table.insert(tests, {
	name = "QueryLogsAction: returns entries from buffer (tail default)",
	fn = function()
		local router = ActionRouter.new()
		local buffer = MessageBuffer.new(100)
		QueryLogsAction.register(router, buffer)

		buffer:push({ level = "Print", body = "first", timestamp = 1000 })
		buffer:push({ level = "Warning", body = "second", timestamp = 2000 })
		buffer:push({ level = "Error", body = "third", timestamp = 3000 })
		buffer:push({ level = "Print", body = "fourth", timestamp = 4000 })
		buffer:push({ level = "Print", body = "fifth", timestamp = 5000 })

		local response = router:dispatch({
			type = "queryLogs",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = { count = 3 },
		})

		assertNotNil(response)
		assertEqual(response.type, "logsResult")
		assertEqual(#response.payload.entries, 3)
		assertEqual(response.payload.entries[1].body, "third")
		assertEqual(response.payload.entries[2].body, "fourth")
		assertEqual(response.payload.entries[3].body, "fifth")
		assertEqual(response.payload.total, 5)
	end,
})

table.insert(tests, {
	name = "QueryLogsAction: head direction returns oldest",
	fn = function()
		local router = ActionRouter.new()
		local buffer = MessageBuffer.new(100)
		QueryLogsAction.register(router, buffer)

		buffer:push({ level = "Print", body = "first", timestamp = 1000 })
		buffer:push({ level = "Print", body = "second", timestamp = 2000 })
		buffer:push({ level = "Print", body = "third", timestamp = 3000 })

		local response = router:dispatch({
			type = "queryLogs",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = { direction = "head", count = 2 },
		})

		assertNotNil(response)
		assertEqual(#response.payload.entries, 2)
		assertEqual(response.payload.entries[1].body, "first")
		assertEqual(response.payload.entries[2].body, "second")
	end,
})

table.insert(tests, {
	name = "QueryLogsAction: level filter only includes matching levels",
	fn = function()
		local router = ActionRouter.new()
		local buffer = MessageBuffer.new(100)
		QueryLogsAction.register(router, buffer)

		buffer:push({ level = "Print", body = "info msg", timestamp = 1000 })
		buffer:push({ level = "Warning", body = "warn msg", timestamp = 2000 })
		buffer:push({ level = "Error", body = "err msg", timestamp = 3000 })
		buffer:push({ level = "Print", body = "another info", timestamp = 4000 })

		local response = router:dispatch({
			type = "queryLogs",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = { levels = { "Warning", "Error" }, count = 50 },
		})

		assertNotNil(response)
		assertEqual(#response.payload.entries, 2)
		assertEqual(response.payload.entries[1].body, "warn msg")
		assertEqual(response.payload.entries[2].body, "err msg")
	end,
})

table.insert(tests, {
	name = "QueryLogsAction: includeInternal=false filters [StudioBridge] messages",
	fn = function()
		local router = ActionRouter.new()
		local buffer = MessageBuffer.new(100)
		QueryLogsAction.register(router, buffer)

		buffer:push({ level = "Print", body = "[StudioBridge] Connected", timestamp = 1000 })
		buffer:push({ level = "Print", body = "user message", timestamp = 2000 })
		buffer:push({ level = "Print", body = "[StudioBridge] Searching...", timestamp = 3000 })
		buffer:push({ level = "Print", body = "another message", timestamp = 4000 })

		local response = router:dispatch({
			type = "queryLogs",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = { count = 50 },
		})

		assertNotNil(response)
		assertEqual(#response.payload.entries, 2, "should filter out [StudioBridge] messages")
		assertEqual(response.payload.entries[1].body, "user message")
		assertEqual(response.payload.entries[2].body, "another message")
	end,
})

table.insert(tests, {
	name = "QueryLogsAction: includeInternal=true keeps [StudioBridge] messages",
	fn = function()
		local router = ActionRouter.new()
		local buffer = MessageBuffer.new(100)
		QueryLogsAction.register(router, buffer)

		buffer:push({ level = "Print", body = "[StudioBridge] Connected", timestamp = 1000 })
		buffer:push({ level = "Print", body = "user message", timestamp = 2000 })

		local response = router:dispatch({
			type = "queryLogs",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = { count = 50, includeInternal = true },
		})

		assertNotNil(response)
		assertEqual(#response.payload.entries, 2, "should include [StudioBridge] messages")
		assertEqual(response.payload.entries[1].body, "[StudioBridge] Connected")
	end,
})

table.insert(tests, {
	name = "QueryLogsAction: empty buffer returns empty entries",
	fn = function()
		local router = ActionRouter.new()
		local buffer = MessageBuffer.new(100)
		QueryLogsAction.register(router, buffer)

		local response = router:dispatch({
			type = "queryLogs",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = {},
		})

		assertNotNil(response)
		assertEqual(#response.payload.entries, 0)
		assertEqual(response.payload.total, 0)
		assertEqual(response.payload.bufferCapacity, 100)
	end,
})

-- ===========================================================================
-- CaptureScreenshotAction
-- ===========================================================================
-- In Lune, game:GetService is not available, so the handler sends a
-- CAPTURE_FAILED error (services not available). The handler runs in a
-- spawned thread, so we need task.wait() to let it execute.

table.insert(tests, {
	name = "CaptureScreenshotAction: sends error via sendMessage (services unavailable in Lune)",
	fn = function()
		local router = ActionRouter.new()
		local sentMessages = {}
		CaptureScreenshotAction.register(router, function(msg)
			table.insert(sentMessages, msg)
		end)

		local response = router:dispatch({
			type = "captureScreenshot",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = {},
		})

		-- Handler returns nil, so router produces no wrapped response
		assertEqual(response, nil, "router should not produce a response")

		-- In Lune, the function runs synchronously (task.spawn unavailable)
		assertEqual(#sentMessages, 1, "one message sent")
		assertEqual(sentMessages[1].type, "error")
		assertEqual(sentMessages[1].payload.code, "CAPTURE_FAILED")
		assertEqual(sentMessages[1].requestId, "req-1")
		assertEqual(sentMessages[1].sessionId, "sess-1")
	end,
})

table.insert(tests, {
	name = "CaptureScreenshotAction: omits requestId when empty",
	fn = function()
		local router = ActionRouter.new()
		local sentMessages = {}
		CaptureScreenshotAction.register(router, function(msg)
			table.insert(sentMessages, msg)
		end)

		router:dispatch({
			type = "captureScreenshot",
			sessionId = "sess-2",
			requestId = "",
			payload = {},
		})

		assertEqual(#sentMessages, 1)
		assertEqual(sentMessages[1].requestId, nil, "requestId should be nil for empty string")
	end,
})

table.insert(tests, {
	name = "CaptureScreenshotAction: returns error payload when no sendMessage provided",
	fn = function()
		local router = ActionRouter.new()
		CaptureScreenshotAction.register(router, nil)

		local response = router:dispatch({
			type = "captureScreenshot",
			sessionId = "sess-3",
			requestId = "req-3",
			payload = {},
		})

		assertNotNil(response, "should return a wrapped response")
		assertEqual(response.type, "screenshotResult")
		assertEqual(response.payload.code, "CAPABILITY_NOT_SUPPORTED")
	end,
})

-- ===========================================================================
-- SubscribeAction stubs
-- ===========================================================================

table.insert(tests, {
	name = "SubscribeAction: echoes back requested events",
	fn = function()
		local router = ActionRouter.new()
		SubscribeAction.register(router)

		local response = router:dispatch({
			type = "subscribe",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = { events = { "stateChange", "logPush" } },
		})

		assertNotNil(response)
		assertEqual(response.type, "subscribeResult")
		assertEqual(#response.payload.events, 2)
		assertEqual(response.payload.events[1], "stateChange")
		assertEqual(response.payload.events[2], "logPush")
	end,
})

table.insert(tests, {
	name = "UnsubscribeAction: echoes back requested events",
	fn = function()
		local router = ActionRouter.new()
		SubscribeAction.register(router)

		local response = router:dispatch({
			type = "unsubscribe",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = { events = { "stateChange" } },
		})

		assertNotNil(response)
		assertEqual(response.type, "unsubscribeResult")
		assertEqual(#response.payload.events, 1)
		assertEqual(response.payload.events[1], "stateChange")
	end,
})

table.insert(tests, {
	name = "SubscribeAction: handles nil events gracefully",
	fn = function()
		local router = ActionRouter.new()
		SubscribeAction.register(router)

		local response = router:dispatch({
			type = "subscribe",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = {},
		})

		assertNotNil(response)
		assertEqual(response.type, "subscribeResult")
		assertEqual(#response.payload.events, 0, "empty events when nil")
	end,
})

return tests
