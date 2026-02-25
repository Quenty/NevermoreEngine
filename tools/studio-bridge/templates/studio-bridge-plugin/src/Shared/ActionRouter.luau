--[[
	Action dispatch module for routing incoming protocol messages to handlers.

	Maintains a registry of handler functions keyed by message type. When a
	message is dispatched, the router looks up the handler, calls it with
	(payload, requestId, sessionId), and constructs a response message if
	the handler returns a payload table.

	Error handling:
	- Unknown message type: returns error response with code UNKNOWN_REQUEST
	- Handler throws: returns error response with code INTERNAL_ERROR
	- Handler returns nil: no response is generated

	No Roblox APIs. Pure logic, testable under Lune.
]]

local ActionRouter = {}
ActionRouter.__index = ActionRouter

-- ---------------------------------------------------------------------------
-- Default response type mapping
-- ---------------------------------------------------------------------------

local DEFAULT_RESPONSE_TYPES: { [string]: string } = {
	execute = "scriptComplete",
	queryState = "stateResult",
	captureScreenshot = "screenshotResult",
	queryDataModel = "dataModelResult",
	queryLogs = "logsResult",
	subscribe = "subscribeResult",
	unsubscribe = "unsubscribeResult",
}

-- ---------------------------------------------------------------------------
-- Constructor
-- ---------------------------------------------------------------------------

function ActionRouter.new()
	-- Copy default response types so each instance can be extended
	local responseTypes = {}
	for k, v in DEFAULT_RESPONSE_TYPES do
		responseTypes[k] = v
	end

	local self = setmetatable({
		_handlers = {} :: {
			[string]: (payload: { [string]: any }, requestId: string, sessionId: string) -> { [string]: any }?,
		},
		_responseTypes = responseTypes,
	}, ActionRouter)
	return self
end

-- ---------------------------------------------------------------------------
-- Register a handler for a message type
-- ---------------------------------------------------------------------------

function ActionRouter.register(
	self: any,
	messageType: string,
	handler: (
		payload: { [string]: any },
		requestId: string,
		sessionId: string
	) -> { [string]: any }?
)
	self._handlers[messageType] = handler
end

-- ---------------------------------------------------------------------------
-- Dispatch an incoming message
-- ---------------------------------------------------------------------------

--[[
	Dispatch an incoming message to the appropriate handler.

	@param message Table with fields: type, sessionId, payload, requestId?
	@return A response message table, or nil if the handler returns nil.
]]
function ActionRouter.dispatch(
	self: any,
	message: {
		type: string,
		sessionId: string,
		payload: { [string]: any },
		requestId: string?,
	}
): { [string]: any }?
	local handler = self._handlers[message.type]

	if handler == nil then
		return {
			type = "error",
			sessionId = message.sessionId,
			requestId = message.requestId,
			payload = {
				code = "UNKNOWN_REQUEST",
				message = "Unknown message type: " .. tostring(message.type),
			},
		}
	end

	local requestId = message.requestId or ""
	local ok, result = pcall(handler, message.payload, requestId, message.sessionId)

	if not ok then
		return {
			type = "error",
			sessionId = message.sessionId,
			requestId = message.requestId,
			payload = {
				code = "INTERNAL_ERROR",
				message = "Handler error: " .. tostring(result),
			},
		}
	end

	if result == nil then
		return nil
	end

	-- Construct response with the appropriate response type
	local responseType = self._responseTypes[message.type] or (message.type .. "Result")

	return {
		type = responseType,
		sessionId = message.sessionId,
		requestId = message.requestId,
		payload = result,
	}
end

-- ---------------------------------------------------------------------------
-- Set a custom response type for a message type
-- ---------------------------------------------------------------------------

function ActionRouter.setResponseType(self: any, messageType: string, responseType: string)
	self._responseTypes[messageType] = responseType
end

-- ---------------------------------------------------------------------------
-- Register a dynamic action from source code
-- ---------------------------------------------------------------------------

--[[
	Dynamically register an action from Luau source code received over the wire.

	The source is expected to be a module that returns a table with a `register`
	function: `function(router, sendMessage?, logBuffer?)`. This mirrors the
	static action module convention.

	If the source defines a simple handler function instead, it is registered
	directly as the handler for the given action name.

	@param name The action name (used as the message type if not registered otherwise).
	@param source The Luau source code string.
	@param sendMessage Optional callback for actions that send their own responses.
	@param logBuffer Optional log buffer instance.
	@param responseType Optional response type override.
	@return success, error?
]]
function ActionRouter.registerAction(
	self: any,
	name: string,
	source: string,
	sendMessage: ((msg: { [string]: any }) -> ())?,
	logBuffer: any?,
	responseType: string?
): (boolean, string?)
	-- Load the source code
	local loadOk, moduleOrErr = pcall(function()
		return (loadstring :: any)(source, `@action/{name}`)
	end)

	if not loadOk or not moduleOrErr then
		return false, `Failed to load action source: {moduleOrErr or "loadstring returned nil"}`
	end

	-- Execute the loaded chunk to get the module table
	local execOk, moduleTable = pcall(moduleOrErr)
	if not execOk then
		return false, `Failed to execute action module: {moduleTable}`
	end

	-- If the module has a register function, call it
	if type(moduleTable) == "table" and type(moduleTable.register) == "function" then
		local regOk, regErr = pcall(moduleTable.register, self, sendMessage, logBuffer)
		if not regOk then
			return false, `register() failed: {regErr}`
		end
	elseif type(moduleTable) == "function" then
		-- Simple handler function
		self:register(name, moduleTable)
	else
		return false, `Action module must return a table with .register() or a function`
	end

	-- Set custom response type if provided
	if responseType then
		self._responseTypes[name] = responseType
	end

	return true, nil
end

return ActionRouter
