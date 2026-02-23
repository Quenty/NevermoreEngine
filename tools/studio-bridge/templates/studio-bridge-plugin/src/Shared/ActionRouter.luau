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
-- Response type mapping
-- ---------------------------------------------------------------------------

local RESPONSE_TYPES: { [string]: string } = {
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
	local self = setmetatable({
		_handlers = {} :: { [string]: (payload: { [string]: any }, requestId: string, sessionId: string) -> { [string]: any }? },
	}, ActionRouter)
	return self
end

-- ---------------------------------------------------------------------------
-- Register a handler for a message type
-- ---------------------------------------------------------------------------

function ActionRouter.register(self: any, messageType: string, handler: (payload: { [string]: any }, requestId: string, sessionId: string) -> { [string]: any }?)
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
function ActionRouter.dispatch(self: any, message: {
	type: string,
	sessionId: string,
	payload: { [string]: any },
	requestId: string?,
}): { [string]: any }?
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
	local responseType = RESPONSE_TYPES[message.type] or (message.type .. "Result")

	return {
		type = responseType,
		sessionId = message.sessionId,
		requestId = message.requestId,
		payload = result,
	}
end

return ActionRouter
