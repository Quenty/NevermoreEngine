--[[
	Tests for Phase 2 action lifecycle: hash-based skip, handler tracking,
	getInstalledActions, and syncActions.

	Validates that:
	- registerAction with same hash skips re-registration
	- registerAction with different hash re-registers (replaces old handlers)
	- registerAction without hash always re-registers
	- getInstalledActions returns correct hash map
	- syncActions returns correct needed/installed lists
	- Handler tracking captures newly registered handler names
]]

local ActionRouter = require("../../studio-bridge-plugin/src/Shared/ActionRouter")

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

local function assertNil(value: any, label: string?)
	if value ~= nil then
		error(string.format("%sexpected nil, got %s", if label then label .. ": " else "", tostring(value)))
	end
end

local function assertTableContains(tbl: { any }, value: any, label: string?)
	for _, v in tbl do
		if v == value then
			return
		end
	end
	error(string.format(
		"%sexpected table to contain '%s'",
		if label then label .. ": " else "",
		tostring(value)
	))
end

-- ---------------------------------------------------------------------------
-- Shared action source helpers
-- ---------------------------------------------------------------------------

-- A simple action module that registers a handler named "testAction"
local SIMPLE_ACTION_SOURCE = [[
local M = {}
function M.register(router, sendMessage, logBuffer)
	router:register("testAction", function(payload, requestId, sessionId)
		return { result = "v1" }
	end)
	router:setResponseType("testAction", "testActionResult")
end
return M
]]

-- A different version of the same action module
local SIMPLE_ACTION_SOURCE_V2 = [[
local M = {}
function M.register(router, sendMessage, logBuffer)
	router:register("testAction", function(payload, requestId, sessionId)
		return { result = "v2" }
	end)
	router:setResponseType("testAction", "testActionResult")
end
return M
]]

-- An action module that registers multiple handlers
local MULTI_HANDLER_SOURCE = [[
local M = {}
function M.register(router, sendMessage, logBuffer)
	router:register("sub", function(payload, requestId, sessionId)
		return { subscribed = true }
	end)
	router:setResponseType("sub", "subResult")
	router:register("unsub", function(payload, requestId, sessionId)
		return { unsubscribed = true }
	end)
	router:setResponseType("unsub", "unsubResult")
end
return M
]]

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------

local tests = {}

-- ===========================================================================
-- Hash-based skip tests
-- ===========================================================================

table.insert(tests, {
	name = "registerAction: same hash skips re-registration",
	fn = function()
		local router = ActionRouter.new()
		local hash = "abc123"

		-- First registration should succeed
		local ok1, err1 = router:registerAction("myAction", SIMPLE_ACTION_SOURCE, nil, nil, nil, hash)
		assertTrue(ok1, "first registration should succeed")
		assertNil(err1, "first registration should not error")

		-- Verify the handler works
		local response1 = router:dispatch({
			type = "testAction",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = {},
		})
		assertNotNil(response1, "response from first registration")
		assertEqual(response1.payload.result, "v1")

		-- Second registration with same hash should skip (return true, no error)
		local ok2, err2 = router:registerAction("myAction", SIMPLE_ACTION_SOURCE, nil, nil, nil, hash)
		assertTrue(ok2, "same hash should succeed (skip)")
		assertNil(err2, "same hash should not error")

		-- Handler should still work (unchanged)
		local response2 = router:dispatch({
			type = "testAction",
			sessionId = "sess-2",
			requestId = "req-2",
			payload = {},
		})
		assertNotNil(response2, "response after skip")
		assertEqual(response2.payload.result, "v1", "handler unchanged after skip")
	end,
})

table.insert(tests, {
	name = "registerAction: different hash re-registers action",
	fn = function()
		local router = ActionRouter.new()

		-- Register v1 with hash "abc"
		local ok1, _ = router:registerAction("myAction", SIMPLE_ACTION_SOURCE, nil, nil, nil, "abc")
		assertTrue(ok1, "v1 registration should succeed")

		-- Verify v1 handler
		local r1 = router:dispatch({
			type = "testAction",
			sessionId = "s1",
			requestId = "r1",
			payload = {},
		})
		assertEqual(r1.payload.result, "v1")

		-- Register v2 with different hash "def"
		local ok2, _ = router:registerAction("myAction", SIMPLE_ACTION_SOURCE_V2, nil, nil, nil, "def")
		assertTrue(ok2, "v2 registration should succeed")

		-- Verify v2 handler replaced v1
		local r2 = router:dispatch({
			type = "testAction",
			sessionId = "s2",
			requestId = "r2",
			payload = {},
		})
		assertEqual(r2.payload.result, "v2", "handler should be v2 after re-registration")
	end,
})

table.insert(tests, {
	name = "registerAction: nil hash always re-registers",
	fn = function()
		local router = ActionRouter.new()

		-- Register without hash
		local ok1, _ = router:registerAction("myAction", SIMPLE_ACTION_SOURCE, nil, nil, nil, nil)
		assertTrue(ok1, "first registration should succeed")

		-- Register again without hash - should not skip
		local ok2, _ = router:registerAction("myAction", SIMPLE_ACTION_SOURCE_V2, nil, nil, nil, nil)
		assertTrue(ok2, "second registration should succeed")

		-- Should be v2
		local r = router:dispatch({
			type = "testAction",
			sessionId = "s1",
			requestId = "r1",
			payload = {},
		})
		assertEqual(r.payload.result, "v2", "handler should be v2 without hash")
	end,
})

-- ===========================================================================
-- Handler tracking tests
-- ===========================================================================

table.insert(tests, {
	name = "registerAction: tracks handler names in _actions",
	fn = function()
		local router = ActionRouter.new()

		router:registerAction("myAction", SIMPLE_ACTION_SOURCE, nil, nil, nil, "hash1")

		local actionInfo = router._actions["myAction"]
		assertNotNil(actionInfo, "action should be tracked")
		assertEqual(actionInfo.hash, "hash1", "hash should be stored")
		assertNotNil(actionInfo.handlerNames, "handlerNames should exist")
		assertEqual(#actionInfo.handlerNames, 1, "should have one handler")
		assertEqual(actionInfo.handlerNames[1], "testAction", "handler name should be testAction")
	end,
})

table.insert(tests, {
	name = "registerAction: tracks multiple handler names from one module",
	fn = function()
		local router = ActionRouter.new()

		router:registerAction("multiAction", MULTI_HANDLER_SOURCE, nil, nil, nil, "multi-hash")

		local actionInfo = router._actions["multiAction"]
		assertNotNil(actionInfo, "action should be tracked")
		assertEqual(#actionInfo.handlerNames, 2, "should have two handlers")

		-- The order may vary, so check both are present
		local hasSub = false
		local hasUnsub = false
		for _, name in actionInfo.handlerNames do
			if name == "sub" then hasSub = true end
			if name == "unsub" then hasUnsub = true end
		end
		assertTrue(hasSub, "should have 'sub' handler")
		assertTrue(hasUnsub, "should have 'unsub' handler")
	end,
})

table.insert(tests, {
	name = "registerAction: re-registration removes old handlers before adding new ones",
	fn = function()
		local router = ActionRouter.new()

		-- Register multi-handler action
		router:registerAction("multiAction", MULTI_HANDLER_SOURCE, nil, nil, nil, "hash-old")

		-- Both handlers should work
		local r1 = router:dispatch({
			type = "sub",
			sessionId = "s1",
			requestId = "r1",
			payload = {},
		})
		assertNotNil(r1, "sub handler should exist")
		assertEqual(r1.payload.subscribed, true)

		-- Re-register with a single-handler action (different hash)
		local SINGLE_SOURCE = [[
local M = {}
function M.register(router, sendMessage, logBuffer)
	router:register("newHandler", function(payload, requestId, sessionId)
		return { new = true }
	end)
end
return M
]]
		router:registerAction("multiAction", SINGLE_SOURCE, nil, nil, nil, "hash-new")

		-- Old handlers should be removed
		local r2 = router:dispatch({
			type = "sub",
			sessionId = "s2",
			requestId = "r2",
			payload = {},
		})
		assertEqual(r2.type, "error", "old 'sub' handler should be removed")
		assertEqual(r2.payload.code, "UNKNOWN_REQUEST")

		-- New handler should work
		local r3 = router:dispatch({
			type = "newHandler",
			sessionId = "s3",
			requestId = "r3",
			payload = {},
		})
		assertNotNil(r3, "newHandler should exist")
		assertEqual(r3.payload.new, true)
	end,
})

-- ===========================================================================
-- getInstalledActions tests
-- ===========================================================================

table.insert(tests, {
	name = "getInstalledActions: returns empty map for fresh router",
	fn = function()
		local router = ActionRouter.new()
		local installed = router:getInstalledActions()
		local count = 0
		for _ in installed do
			count = count + 1
		end
		assertEqual(count, 0, "should be empty")
	end,
})

table.insert(tests, {
	name = "getInstalledActions: returns correct hash map after registrations",
	fn = function()
		local router = ActionRouter.new()

		router:registerAction("action1", SIMPLE_ACTION_SOURCE, nil, nil, nil, "hash-aaa")
		router:registerAction("action2", MULTI_HANDLER_SOURCE, nil, nil, nil, "hash-bbb")

		local installed = router:getInstalledActions()
		assertEqual(installed["action1"], "hash-aaa", "action1 hash")
		assertEqual(installed["action2"], "hash-bbb", "action2 hash")
	end,
})

table.insert(tests, {
	name = "getInstalledActions: reflects updated hash after re-registration",
	fn = function()
		local router = ActionRouter.new()

		router:registerAction("myAction", SIMPLE_ACTION_SOURCE, nil, nil, nil, "old-hash")
		assertEqual(router:getInstalledActions()["myAction"], "old-hash")

		router:registerAction("myAction", SIMPLE_ACTION_SOURCE_V2, nil, nil, nil, "new-hash")
		assertEqual(router:getInstalledActions()["myAction"], "new-hash", "hash should update")
	end,
})

table.insert(tests, {
	name = "getInstalledActions: does not include actions registered without hash",
	fn = function()
		local router = ActionRouter.new()

		router:registerAction("noHash", SIMPLE_ACTION_SOURCE, nil, nil, nil, nil)
		router:registerAction("withHash", MULTI_HANDLER_SOURCE, nil, nil, nil, "some-hash")

		local installed = router:getInstalledActions()
		assertNil(installed["noHash"], "no-hash action should not appear")
		assertEqual(installed["withHash"], "some-hash", "hashed action should appear")
	end,
})

-- ===========================================================================
-- syncActions handler tests (via dispatch)
-- ===========================================================================

table.insert(tests, {
	name = "syncActions: identifies needed actions when none installed",
	fn = function()
		local router = ActionRouter.new()

		-- Register the syncActions handler (simulating what StudioBridgePlugin does)
		router:register("syncActions", function(payload, requestId, sessionId)
			local clientActions = payload.actions or {}
			local installed = router:getInstalledActions()
			local needed = {}

			for name, clientHash in clientActions do
				if installed[name] ~= clientHash then
					table.insert(needed, name)
				end
			end

			return { needed = needed, installed = installed }
		end)
		router:setResponseType("syncActions", "syncActionsResult")

		local response = router:dispatch({
			type = "syncActions",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = {
				actions = {
					exec = "hash-exec",
					logs = "hash-logs",
				},
			},
		})

		assertNotNil(response)
		assertEqual(response.type, "syncActionsResult")
		assertEqual(#response.payload.needed, 2, "both should be needed")
	end,
})

table.insert(tests, {
	name = "syncActions: skips already-installed matching hashes",
	fn = function()
		local router = ActionRouter.new()

		-- Install one action with a known hash
		router:registerAction("action1", SIMPLE_ACTION_SOURCE, nil, nil, nil, "hash-aaa")

		-- Register syncActions handler
		router:register("syncActions", function(payload, requestId, sessionId)
			local clientActions = payload.actions or {}
			local installed = router:getInstalledActions()
			local needed = {}

			for name, clientHash in clientActions do
				if installed[name] ~= clientHash then
					table.insert(needed, name)
				end
			end

			return { needed = needed, installed = installed }
		end)
		router:setResponseType("syncActions", "syncActionsResult")

		local response = router:dispatch({
			type = "syncActions",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = {
				actions = {
					action1 = "hash-aaa",   -- matches installed
					action2 = "hash-bbb",   -- not installed
				},
			},
		})

		assertNotNil(response)
		assertEqual(#response.payload.needed, 1, "only one should be needed")
		assertEqual(response.payload.needed[1], "action2", "action2 should be needed")
		assertEqual(response.payload.installed["action1"], "hash-aaa", "installed should include action1")
	end,
})

table.insert(tests, {
	name = "syncActions: detects hash mismatch for installed actions",
	fn = function()
		local router = ActionRouter.new()

		-- Install action with hash "old-hash"
		router:registerAction("myAction", SIMPLE_ACTION_SOURCE, nil, nil, nil, "old-hash")

		-- Register syncActions handler
		router:register("syncActions", function(payload, requestId, sessionId)
			local clientActions = payload.actions or {}
			local installed = router:getInstalledActions()
			local needed = {}

			for name, clientHash in clientActions do
				if installed[name] ~= clientHash then
					table.insert(needed, name)
				end
			end

			return { needed = needed, installed = installed }
		end)
		router:setResponseType("syncActions", "syncActionsResult")

		local response = router:dispatch({
			type = "syncActions",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = {
				actions = {
					myAction = "new-hash",  -- different from installed
				},
			},
		})

		assertNotNil(response)
		assertEqual(#response.payload.needed, 1, "mismatched hash should be needed")
		assertEqual(response.payload.needed[1], "myAction")
	end,
})

table.insert(tests, {
	name = "syncActions: empty client actions returns empty needed",
	fn = function()
		local router = ActionRouter.new()

		router:registerAction("myAction", SIMPLE_ACTION_SOURCE, nil, nil, nil, "some-hash")

		-- Register syncActions handler
		router:register("syncActions", function(payload, requestId, sessionId)
			local clientActions = payload.actions or {}
			local installed = router:getInstalledActions()
			local needed = {}

			for name, clientHash in clientActions do
				if installed[name] ~= clientHash then
					table.insert(needed, name)
				end
			end

			return { needed = needed, installed = installed }
		end)
		router:setResponseType("syncActions", "syncActionsResult")

		local response = router:dispatch({
			type = "syncActions",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = {},
		})

		assertNotNil(response)
		assertEqual(#response.payload.needed, 0, "nothing should be needed")
		assertEqual(response.payload.installed["myAction"], "some-hash")
	end,
})

-- ===========================================================================
-- registerAction handler response format (simulating plugin handler)
-- ===========================================================================

table.insert(tests, {
	name = "registerAction handler: returns skipped=true for matching hash",
	fn = function()
		local router = ActionRouter.new()

		-- Simulate the registerAction built-in handler from StudioBridgePlugin
		router:register("registerAction", function(payload, requestId, sessionId)
			local name = payload.name
			local source = payload.source
			local hash = payload.hash

			if type(hash) == "string" and router._actions[name] and router._actions[name].hash == hash then
				return {
					name = name,
					success = true,
					skipped = true,
					hash = hash,
					handlers = router._actions[name].handlerNames,
				}
			end

			local success, err = router:registerAction(name, source, nil, nil, nil, hash)
			local handlers = {}
			if success and router._actions[name] then
				handlers = router._actions[name].handlerNames
			end

			return {
				name = name,
				success = success,
				skipped = false,
				hash = hash,
				handlers = handlers,
				error = err,
			}
		end)
		router:setResponseType("registerAction", "registerActionResult")

		-- First registration
		local r1 = router:dispatch({
			type = "registerAction",
			sessionId = "sess-1",
			requestId = "req-1",
			payload = { name = "myAction", source = SIMPLE_ACTION_SOURCE, hash = "abc123" },
		})
		assertNotNil(r1)
		assertEqual(r1.type, "registerActionResult")
		assertTrue(r1.payload.success, "first registration should succeed")
		assertFalse(r1.payload.skipped, "first registration should not be skipped")
		assertEqual(r1.payload.hash, "abc123")
		assertEqual(#r1.payload.handlers, 1)
		assertEqual(r1.payload.handlers[1], "testAction")

		-- Second registration with same hash
		local r2 = router:dispatch({
			type = "registerAction",
			sessionId = "sess-2",
			requestId = "req-2",
			payload = { name = "myAction", source = SIMPLE_ACTION_SOURCE, hash = "abc123" },
		})
		assertNotNil(r2)
		assertTrue(r2.payload.success, "skip registration should succeed")
		assertTrue(r2.payload.skipped, "same hash should be skipped")
		assertEqual(r2.payload.hash, "abc123")
		assertEqual(#r2.payload.handlers, 1)
	end,
})

table.insert(tests, {
	name = "registerAction handler: returns new handlers on hash change",
	fn = function()
		local router = ActionRouter.new()

		-- Simplified registerAction handler
		router:register("registerAction", function(payload, requestId, sessionId)
			local name = payload.name
			local source = payload.source
			local hash = payload.hash

			if type(hash) == "string" and router._actions[name] and router._actions[name].hash == hash then
				return {
					name = name,
					success = true,
					skipped = true,
					hash = hash,
					handlers = router._actions[name].handlerNames,
				}
			end

			local success, err = router:registerAction(name, source, nil, nil, nil, hash)
			local handlers = {}
			if success and router._actions[name] then
				handlers = router._actions[name].handlerNames
			end

			return {
				name = name,
				success = success,
				skipped = false,
				hash = hash,
				handlers = handlers,
				error = err,
			}
		end)
		router:setResponseType("registerAction", "registerActionResult")

		-- Register v1
		router:dispatch({
			type = "registerAction",
			sessionId = "s1",
			requestId = "r1",
			payload = { name = "myAction", source = SIMPLE_ACTION_SOURCE, hash = "hash-v1" },
		})

		-- Register v2 with different hash
		local r = router:dispatch({
			type = "registerAction",
			sessionId = "s2",
			requestId = "r2",
			payload = { name = "myAction", source = SIMPLE_ACTION_SOURCE_V2, hash = "hash-v2" },
		})

		assertNotNil(r)
		assertTrue(r.payload.success)
		assertFalse(r.payload.skipped, "different hash should not be skipped")
		assertEqual(r.payload.hash, "hash-v2")

		-- Verify v2 handler is active
		local dispatchResult = router:dispatch({
			type = "testAction",
			sessionId = "s3",
			requestId = "r3",
			payload = {},
		})
		assertEqual(dispatchResult.payload.result, "v2", "v2 handler should be active")
	end,
})

-- ===========================================================================
-- Teardown lifecycle tests
-- ===========================================================================

table.insert(tests, {
	name = "teardown: called before re-registration on hash change",
	fn = function()
		local router = ActionRouter.new()

		local teardownCalled = false
		local SOURCE_WITH_TEARDOWN = [[
local M = {}
local _teardownCalled = false
function M.register(router, sendMessage, logBuffer)
	router:register("testAction", function(payload, requestId, sessionId)
		return { result = "v1" }
	end)
end
function M.teardown()
	-- We can't communicate back easily, so we use a global
	_G.__test_teardown_called = true
end
return M
]]
		_G.__test_teardown_called = false

		router:registerAction("myAction", SOURCE_WITH_TEARDOWN, nil, nil, nil, "hash-old")
		assertFalse(_G.__test_teardown_called, "teardown should not be called on first registration")

		-- Re-register with different hash
		local REPLACEMENT_SOURCE = [[
local M = {}
function M.register(router, sendMessage, logBuffer)
	router:register("testAction", function(payload, requestId, sessionId)
		return { result = "v2" }
	end)
end
return M
]]
		router:registerAction("myAction", REPLACEMENT_SOURCE, nil, nil, nil, "hash-new")
		assertTrue(_G.__test_teardown_called, "teardown should be called before re-registration")

		-- Clean up global
		_G.__test_teardown_called = nil
	end,
})

table.insert(tests, {
	name = "teardown: not called when hash matches (skip)",
	fn = function()
		local router = ActionRouter.new()

		local SOURCE_WITH_TEARDOWN = [[
local M = {}
function M.register(router, sendMessage, logBuffer)
	router:register("testAction", function(payload, requestId, sessionId)
		return { result = "v1" }
	end)
end
function M.teardown()
	_G.__test_teardown_called = true
end
return M
]]
		_G.__test_teardown_called = false

		router:registerAction("myAction", SOURCE_WITH_TEARDOWN, nil, nil, nil, "same-hash")
		assertFalse(_G.__test_teardown_called, "teardown should not be called on first registration")

		-- Re-register with same hash (should skip entirely)
		router:registerAction("myAction", SOURCE_WITH_TEARDOWN, nil, nil, nil, "same-hash")
		assertFalse(_G.__test_teardown_called, "teardown should not be called when hash matches")

		_G.__test_teardown_called = nil
	end,
})

table.insert(tests, {
	name = "teardown: missing teardown on simple action does not error",
	fn = function()
		local router = ActionRouter.new()

		-- Register action without teardown function
		router:registerAction("myAction", SIMPLE_ACTION_SOURCE, nil, nil, nil, "hash-old")

		-- Re-register with different hash - should not error
		local ok, err = router:registerAction("myAction", SIMPLE_ACTION_SOURCE_V2, nil, nil, nil, "hash-new")
		assertTrue(ok, "re-registration should succeed without teardown")
		assertNil(err, "should not error")

		-- New handler should work
		local r = router:dispatch({
			type = "testAction",
			sessionId = "s1",
			requestId = "r1",
			payload = {},
		})
		assertEqual(r.payload.result, "v2", "v2 handler should be active")
	end,
})

table.insert(tests, {
	name = "teardown: failure does not block re-registration",
	fn = function()
		local router = ActionRouter.new()

		local FAILING_TEARDOWN_SOURCE = [[
local M = {}
function M.register(router, sendMessage, logBuffer)
	router:register("testAction", function(payload, requestId, sessionId)
		return { result = "v1" }
	end)
end
function M.teardown()
	error("teardown exploded!")
end
return M
]]

		router:registerAction("myAction", FAILING_TEARDOWN_SOURCE, nil, nil, nil, "hash-old")

		-- Re-register with different hash - teardown will throw but pcall should catch it
		local ok, err = router:registerAction("myAction", SIMPLE_ACTION_SOURCE_V2, nil, nil, nil, "hash-new")
		assertTrue(ok, "re-registration should succeed despite teardown failure")
		assertNil(err, "should not error")

		-- New handler should work
		local r = router:dispatch({
			type = "testAction",
			sessionId = "s1",
			requestId = "r1",
			payload = {},
		})
		assertEqual(r.payload.result, "v2", "v2 handler should be active despite teardown failure")
	end,
})

return tests
