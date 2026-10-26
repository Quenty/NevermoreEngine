--!strict
--[=[
	Routes incoming studio-bridge messages to handlers by message type, and wraps
	whatever a handler returns into the response message.

	- An unknown message type answers with an `UNKNOWN_REQUEST` error.
	- A handler that throws answers with an `INTERNAL_ERROR` error.
	- A handler that returns nil sends nothing, which is how an action that
	  replies on its own (through `sendMessage`) opts out.

	Action modules pushed over the wire call `register` and `setResponseType` on
	the router. Those two keep their lowercase names because a persistent plugin
	installed from an older release still runs action source pushed by a newer CLI.

	@class ActionRouter
]=]

local ActionRouter = {}
ActionRouter.ClassName = "ActionRouter"
ActionRouter.__index = ActionRouter

export type Message = {
	type: string,
	sessionId: string,
	payload: { [string]: any },
	requestId: string?,
}

export type Handler = (payload: { [string]: any }, requestId: string, sessionId: string) -> { [string]: any }?

export type SendMessage = (message: { [string]: any }) -> ()

export type ActionInfo = {
	module: any,
	hash: string,
	handlerNames: { string },
}

export type ActionRouter = typeof(setmetatable(
	{} :: {
		_handlers: { [string]: Handler },
		_responseTypes: { [string]: string },
		_actions: { [string]: ActionInfo },
		_vendorPng: any?,
	},
	{} :: typeof({ __index = ActionRouter })
))

--[=[
	Constructs a new router with no handlers.
]=]
function ActionRouter.new(): ActionRouter
	local self: ActionRouter = setmetatable({} :: any, ActionRouter)

	self._handlers = {}
	self._responseTypes = {}
	self._actions = {}

	-- The screenshot action reads its PNG encoder off this field
	self._vendorPng = nil

	return self
end

--[=[
	Sets the handler for a message type, replacing any previous one.
]=]
function ActionRouter.register(self: ActionRouter, messageType: string, handler: Handler)
	self._handlers[messageType] = handler
end

--[=[
	Overrides the response type for a message type. Defaults to `<messageType>Result`.
]=]
function ActionRouter.setResponseType(self: ActionRouter, messageType: string, responseType: string)
	self._responseTypes[messageType] = responseType
end

--[=[
	Sets the PNG encoder handed to the screenshot action.
]=]
function ActionRouter.SetVendorPng(self: ActionRouter, png: any)
	self._vendorPng = png
end

--[=[
	Dispatches a message to its handler and returns the response message, if any.
]=]
function ActionRouter.Dispatch(self: ActionRouter, message: Message): Message?
	local handler = self._handlers[message.type]
	if handler == nil then
		return ActionRouter._errorResponse(message, "UNKNOWN_REQUEST", `Unknown message type: {tostring(message.type)}`)
	end

	local ok, result = pcall(handler, message.payload, message.requestId or "", message.sessionId)
	if not ok then
		return ActionRouter._errorResponse(message, "INTERNAL_ERROR", `Handler error: {tostring(result)}`)
	end

	if result == nil then
		return nil
	end

	return {
		type = self._responseTypes[message.type] or `{message.type}Result`,
		sessionId = message.sessionId,
		requestId = message.requestId,
		payload = result,
	}
end

function ActionRouter._errorResponse(message: Message, code: string, errorMessage: string): Message
	return {
		type = "error",
		sessionId = message.sessionId,
		requestId = message.requestId,
		payload = {
			code = code,
			message = errorMessage,
		},
	}
end

--[=[
	Installs an action from Luau source received over the wire.

	The source returns either a table with `register(router, sendMessage?, logBuffer?)`
	(and optionally `teardown()`), or a bare handler function registered under `name`.

	Re-registering a name tears the previous module down and removes its handlers
	first. With a `hash`, the same hash installed twice is a no-op.
]=]
function ActionRouter.RegisterAction(
	self: ActionRouter,
	name: string,
	source: string,
	sendMessage: SendMessage?,
	logBuffer: any?,
	responseType: string?,
	hash: string?
): (boolean, string?)
	local oldAction = self._actions[name]
	if hash and oldAction and oldAction.hash == hash then
		return true, nil
	end

	if oldAction then
		if type(oldAction.module) == "table" and type(oldAction.module.teardown) == "function" then
			pcall(oldAction.module.teardown)
		end
		for _, handlerName in oldAction.handlerNames do
			self._handlers[handlerName] = nil
			self._responseTypes[handlerName] = nil
		end
	end

	local handlersBefore: { [string]: boolean } = {}
	for handlerName in self._handlers do
		handlersBefore[handlerName] = true
	end

	local loadOk, chunkOrErr = pcall(function()
		return (loadstring :: any)(source, `@action/{name}`)
	end)
	if not loadOk or not chunkOrErr then
		return false, `Failed to load action source: {chunkOrErr or "loadstring returned nil"}`
	end

	local execOk, moduleOrErr = pcall(chunkOrErr)
	if not execOk then
		return false, `Failed to execute action module: {moduleOrErr}`
	end

	if type(moduleOrErr) == "table" and type(moduleOrErr.register) == "function" then
		local registerOk, registerErr = pcall(moduleOrErr.register, self, sendMessage, logBuffer)
		if not registerOk then
			return false, `register() failed: {registerErr}`
		end
	elseif type(moduleOrErr) == "function" then
		self:register(name, moduleOrErr)
	else
		return false, "Action module must return a table with .register() or a function"
	end

	if responseType then
		self._responseTypes[name] = responseType
	end

	local handlerNames: { string } = {}
	for handlerName in self._handlers do
		if not handlersBefore[handlerName] then
			table.insert(handlerNames, handlerName)
		end
	end

	if hash then
		self._actions[name] = {
			module = moduleOrErr,
			hash = hash,
			handlerNames = handlerNames,
		}
	end

	return true, nil
end

--[=[
	Returns the handler names an installed action registered, or nil when no
	action with a hash is installed under `name`.
]=]
function ActionRouter.GetActionHandlerNames(self: ActionRouter, name: string): { string }?
	local action = self._actions[name]
	if not action then
		return nil
	end

	return table.clone(action.handlerNames)
end

--[=[
	Returns action name to content hash for every installed action. The bridge
	compares this against its own hashes to decide which actions to push.
]=]
function ActionRouter.GetInstalledActions(self: ActionRouter): { [string]: string }
	local result: { [string]: string } = {}
	for name, action in self._actions do
		result[name] = action.hash
	end
	return result
end

return ActionRouter
