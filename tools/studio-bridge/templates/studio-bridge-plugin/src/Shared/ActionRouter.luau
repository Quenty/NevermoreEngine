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
-- Constructor
-- ---------------------------------------------------------------------------

function ActionRouter.new()
	local self = setmetatable({
		_handlers = {} :: {
			[string]: (payload: { [string]: any }, requestId: string, sessionId: string) -> { [string]: any }?,
		},
		_responseTypes = {} :: { [string]: string },
		_actions = {} :: { [string]: { module: any, hash: string, handlerNames: { string } } },
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
	@param hash Optional content hash for skip-on-same-hash optimization.
	@return success, error?
]]
function ActionRouter.registerAction(
	self: any,
	name: string,
	source: string,
	sendMessage: ((msg: { [string]: any }) -> ())?,
	logBuffer: any?,
	responseType: string?,
	hash: string?
): (boolean, string?)
	-- Hash-based skip: if the same hash is already installed, skip re-registration
	if hash and self._actions[name] and self._actions[name].hash == hash then
		return true, nil
	end

	-- If an old module exists, tear it down and remove its handlers
	local oldAction = self._actions[name]
	if oldAction then
		if type(oldAction.module.teardown) == "function" then
			pcall(oldAction.module.teardown)
		end
		for _, handlerName in oldAction.handlerNames do
			self._handlers[handlerName] = nil
			self._responseTypes[handlerName] = nil
		end
	end

	-- Snapshot handler keys before registration
	local beforeHandlers = {}
	for k, _ in self._handlers do
		beforeHandlers[k] = true
	end

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

	-- Diff handler keys to find newly registered handler names
	local registeredNames = {}
	for k, _ in self._handlers do
		if not beforeHandlers[k] then
			table.insert(registeredNames, k)
		end
	end

	-- Store in _actions for hash tracking
	if hash then
		self._actions[name] = {
			module = moduleTable,
			hash = hash,
			handlerNames = registeredNames,
		}
	end

	return true, nil
end

-- ---------------------------------------------------------------------------
-- Get installed actions with their hashes
-- ---------------------------------------------------------------------------

--[[
	Returns a map of action name -> content hash for all installed actions.
	Used by the syncActions protocol to determine which actions need updating.
]]
function ActionRouter.getInstalledActions(self: any): { [string]: string }
	local result = {}
	for name, info in self._actions do
		result[name] = info.hash
	end
	return result
end

return ActionRouter
