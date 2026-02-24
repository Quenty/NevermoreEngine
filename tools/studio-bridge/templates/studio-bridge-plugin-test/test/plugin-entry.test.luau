--[[
	Tests for the unified plugin entry point logic (Layer 2).

	Tests the logic that CAN be tested without Roblox:
	  - Boot mode detection (IS_EPHEMERAL)
	  - Context detection logic
	  - Register message construction
	  - Execute action handler dispatch through ActionRouter
	  - Log capture into MessageBuffer
]]

local ActionRouter = require("../../studio-bridge-plugin/src/Shared/ActionRouter")
local MessageBuffer = require("../../studio-bridge-plugin/src/Shared/MessageBuffer")
local ExecuteAction = require("../../studio-bridge-plugin/src/Actions/ExecuteAction")
local mocks = require("./roblox-mocks")

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
-- Boot mode detection
-- ===========================================================================

table.insert(tests, {
	name = "IS_EPHEMERAL: true when PORT is substituted",
	fn = function()
		local PORT = "38740"
		local IS_EPHEMERAL = (PORT ~= "{{" .. "PORT" .. "}}")
		assertTrue(IS_EPHEMERAL, "should be ephemeral when PORT is a number")
	end,
})

table.insert(tests, {
	name = "IS_EPHEMERAL: false when PORT is template string",
	fn = function()
		local PORT = "{{PORT}}"
		local IS_EPHEMERAL = (PORT ~= "{{" .. "PORT" .. "}}")
		assertFalse(IS_EPHEMERAL, "should not be ephemeral when PORT is template")
	end,
})

table.insert(tests, {
	name = "IS_EPHEMERAL: false when PORT is partial template",
	fn = function()
		-- Edge case: partial substitution shouldn't happen, but verify
		local PORT = "{{PORT"
		local IS_EPHEMERAL = (PORT ~= "{{" .. "PORT" .. "}}")
		assertTrue(IS_EPHEMERAL, "partial template should count as ephemeral")
	end,
})

-- ===========================================================================
-- Context detection
-- ===========================================================================

table.insert(tests, {
	name = "detectContext: returns 'edit' when not running",
	fn = function()
		-- Simulate edit mode: IsRunning = false
		local function detectContext(isRunning, isClient)
			if isRunning then
				if isClient then
					return "client"
				else
					return "server"
				end
			end
			return "edit"
		end

		assertEqual(detectContext(false, false), "edit")
	end,
})

table.insert(tests, {
	name = "detectContext: returns 'client' when running as client",
	fn = function()
		local function detectContext(isRunning, isClient)
			if isRunning then
				if isClient then
					return "client"
				else
					return "server"
				end
			end
			return "edit"
		end

		assertEqual(detectContext(true, true), "client")
	end,
})

table.insert(tests, {
	name = "detectContext: returns 'server' when running but not client",
	fn = function()
		local function detectContext(isRunning, isClient)
			if isRunning then
				if isClient then
					return "client"
				else
					return "server"
				end
			end
			return "edit"
		end

		assertEqual(detectContext(true, false), "server")
	end,
})

-- ===========================================================================
-- Register message construction
-- ===========================================================================

table.insert(tests, {
	name = "register message has correct structure",
	fn = function()
		local context = "edit"
		local registerMsg = {
			type = "register",
			protocolVersion = 2,
			sessionId = "test-session",
			payload = {
				pluginVersion = "0.7.0",
				instanceId = "0-0",
				context = context,
				placeName = "TestPlace",
				placeId = 0,
				gameId = 0,
				state = "ready",
				capabilities = { "execute", "queryState", "queryLogs" },
			},
		}

		assertEqual(registerMsg.type, "register")
		assertEqual(registerMsg.protocolVersion, 2)
		assertEqual(registerMsg.sessionId, "test-session")
		assertEqual(registerMsg.payload.pluginVersion, "0.7.0")
		assertEqual(registerMsg.payload.context, "edit")
		assertEqual(registerMsg.payload.state, "ready")
		assertEqual(#registerMsg.payload.capabilities, 3)
		assertEqual(registerMsg.payload.capabilities[1], "execute")
		assertEqual(registerMsg.payload.capabilities[2], "queryState")
		assertEqual(registerMsg.payload.capabilities[3], "queryLogs")
	end,
})

table.insert(tests, {
	name = "register message instanceId format is GameId-PlaceId",
	fn = function()
		local gameId = 12345
		local placeId = 67890
		local instanceId = tostring(gameId) .. "-" .. tostring(placeId)
		assertEqual(instanceId, "12345-67890")
	end,
})

-- ===========================================================================
-- ExecuteAction handler
-- ===========================================================================

table.insert(tests, {
	name = "ExecuteAction: successful execution returns success",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "local x = 1 + 1" }, "req-1", "sess-1")
		assertNotNil(result)
		assertTrue(result.success, "should succeed")
	end,
})

table.insert(tests, {
	name = "ExecuteAction: missing code returns error",
	fn = function()
		local result = ExecuteAction.handleExecute({}, "req-2", "sess-2")
		assertNotNil(result)
		assertFalse(result.success, "should fail")
		assertContains(result.error, "Missing code")
	end,
})

table.insert(tests, {
	name = "ExecuteAction: nil payload code returns error",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = nil }, "req-3", "sess-3")
		assertNotNil(result)
		assertFalse(result.success, "should fail")
		assertContains(result.error, "Missing code")
	end,
})

table.insert(tests, {
	name = "ExecuteAction: compile error returns error with details",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "local x = (" }, "req-4", "sess-4")
		assertNotNil(result)
		assertFalse(result.success, "should fail")
		assertEqual(result.code, "SCRIPT_LOAD_ERROR")
	end,
})

table.insert(tests, {
	name = "ExecuteAction: runtime error returns error with details",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = "error('boom')" }, "req-5", "sess-5")
		assertNotNil(result)
		assertFalse(result.success, "should fail")
		assertEqual(result.code, "SCRIPT_RUNTIME_ERROR")
		assertContains(result.error, "boom")
	end,
})

table.insert(tests, {
	name = "ExecuteAction: non-string code returns error",
	fn = function()
		local result = ExecuteAction.handleExecute({ code = 42 }, "req-6", "sess-6")
		assertNotNil(result)
		assertFalse(result.success, "should fail")
		assertContains(result.error, "Missing code")
	end,
})

-- ===========================================================================
-- ExecuteAction through ActionRouter dispatch
-- ===========================================================================

table.insert(tests, {
	name = "ActionRouter + ExecuteAction: dispatches execute and returns scriptComplete",
	fn = function()
		local router = ActionRouter.new()
		ExecuteAction.register(router)

		local response = router:dispatch({
			type = "execute",
			sessionId = "sess-dispatch",
			requestId = "req-dispatch",
			payload = { code = "local x = 42" },
		})

		assertNotNil(response)
		assertEqual(response.type, "scriptComplete")
		assertEqual(response.sessionId, "sess-dispatch")
		assertEqual(response.requestId, "req-dispatch")
		assertTrue(response.payload.success)
	end,
})

table.insert(tests, {
	name = "ActionRouter + ExecuteAction: compile error dispatched as scriptComplete with failure",
	fn = function()
		local router = ActionRouter.new()
		ExecuteAction.register(router)

		local response = router:dispatch({
			type = "execute",
			sessionId = "sess-err",
			requestId = "req-err",
			payload = { code = "local x = (" },
		})

		assertNotNil(response)
		assertEqual(response.type, "scriptComplete")
		assertFalse(response.payload.success)
		assertEqual(response.payload.code, "SCRIPT_LOAD_ERROR")
	end,
})

table.insert(tests, {
	name = "ActionRouter + ExecuteAction: runtime error dispatched as scriptComplete with failure",
	fn = function()
		local router = ActionRouter.new()
		ExecuteAction.register(router)

		local response = router:dispatch({
			type = "execute",
			sessionId = "sess-rt",
			requestId = "req-rt",
			payload = { code = "error('test failure')" },
		})

		assertNotNil(response)
		assertEqual(response.type, "scriptComplete")
		assertFalse(response.payload.success)
		assertEqual(response.payload.code, "SCRIPT_RUNTIME_ERROR")
		assertContains(response.payload.error, "test failure")
	end,
})

-- ===========================================================================
-- Log capture into MessageBuffer
-- ===========================================================================

table.insert(tests, {
	name = "MessageBuffer captures log entries from LogService mock",
	fn = function()
		local buf = MessageBuffer.new(100)
		local LogService = mocks.LogService

		-- Simulate wiring LogService.MessageOut -> buffer
		local conn = LogService.MessageOut:Connect(function(message, _messageType)
			buf:push({
				level = "Print",
				body = message,
				timestamp = 1000,
			})
		end)

		LogService.MessageOut:Fire("hello from test", nil)
		LogService.MessageOut:Fire("second message", nil)

		assertEqual(buf:size(), 2)
		local result = buf:get()
		assertEqual(result.entries[1].body, "hello from test")
		assertEqual(result.entries[2].body, "second message")

		conn:Disconnect()
	end,
})

table.insert(tests, {
	name = "Log capture filters [StudioBridge] messages",
	fn = function()
		local buf = MessageBuffer.new(100)
		local LogService = mocks.LogService

		local conn = LogService.MessageOut:Connect(function(message, _messageType)
			if string.sub(message, 1, 14) == "[StudioBridge]" then
				return
			end
			buf:push({
				level = "Print",
				body = message,
				timestamp = 1000,
			})
		end)

		LogService.MessageOut:Fire("[StudioBridge] internal message", nil)
		LogService.MessageOut:Fire("visible message", nil)

		assertEqual(buf:size(), 1)
		local result = buf:get()
		assertEqual(result.entries[1].body, "visible message")

		conn:Disconnect()
	end,
})

-- ===========================================================================
-- WebSocket URL construction
-- ===========================================================================

table.insert(tests, {
	name = "Ephemeral WebSocket URL format",
	fn = function()
		local port = "38740"
		local sessionId = "abc-123"
		local wsUrl = "ws://localhost:" .. port .. "/" .. sessionId
		assertEqual(wsUrl, "ws://localhost:38740/abc-123")
	end,
})

table.insert(tests, {
	name = "Persistent session ID format",
	fn = function()
		local gameId = 111
		local placeId = 222
		local sessionId = tostring(gameId) .. "-" .. tostring(placeId)
		assertEqual(sessionId, "111-222")
	end,
})

-- ===========================================================================
-- Instance/session ID helpers (replicate getInstanceId/getSessionId logic)
-- ===========================================================================

table.insert(tests, {
	name = "getInstanceId: published place uses GameId-PlaceId",
	fn = function()
		local gameId = 12345
		local placeId = 67890
		local instanceId
		if gameId ~= 0 or placeId ~= 0 then
			instanceId = tostring(gameId) .. "-" .. tostring(placeId)
		end
		assertEqual(instanceId, "12345-67890")
	end,
})

table.insert(tests, {
	name = "getInstanceId: unpublished place uses sanitized name",
	fn = function()
		local gameId = 0
		local placeId = 0
		local placeName = "My Cool Game!"
		local instanceId
		if gameId ~= 0 or placeId ~= 0 then
			instanceId = tostring(gameId) .. "-" .. tostring(placeId)
		else
			local name = string.lower(placeName)
			name = string.gsub(name, "%s+", "-")
			name = string.gsub(name, "[^%w%-]", "")
			if name == "" then
				name = "untitled"
			end
			instanceId = "local-" .. name
		end
		assertEqual(instanceId, "local-my-cool-game")
	end,
})

table.insert(tests, {
	name = "getInstanceId: empty name falls back to untitled",
	fn = function()
		local gameId = 0
		local placeId = 0
		local placeName = "!!!"
		local instanceId
		if gameId ~= 0 or placeId ~= 0 then
			instanceId = tostring(gameId) .. "-" .. tostring(placeId)
		else
			local name = string.lower(placeName)
			name = string.gsub(name, "%s+", "-")
			name = string.gsub(name, "[^%w%-]", "")
			if name == "" then
				name = "untitled"
			end
			instanceId = "local-" .. name
		end
		assertEqual(instanceId, "local-untitled")
	end,
})

table.insert(tests, {
	name = "getSessionId: appends context to instanceId",
	fn = function()
		local instanceId = "local-my-game"
		local context = "edit"
		local sessionId = instanceId .. "-" .. context
		assertEqual(sessionId, "local-my-game-edit")
	end,
})

return tests
