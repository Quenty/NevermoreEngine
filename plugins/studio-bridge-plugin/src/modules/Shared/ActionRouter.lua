--!strict
--[=[
	@class ActionRouter
]=]

local PLANTED_ONLY_MESSAGE =
	'This playtest session runs without plugin permissions, so it can only run code planted when the playtest started. Turn on Studio\'s "Load user plugins on playtest" setting to run any code in it.'

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

export type Compiler = (source: string, chunkName: string?) -> (any, string?)

export type ActionInfo = {
	module: any,
	hash: string,
	handlerNames: { string },
}

export type FailedAction = {
	hash: string,
	error: string,
}

export type ActionRouter = typeof(setmetatable(
	{} :: {
		_handlers: { [string]: Handler },
		_responseTypes: { [string]: string },
		_actions: { [string]: ActionInfo },
		_failedActions: { [string]: FailedAction },
		_vendorPng: any?,
		_compiler: Compiler?,
		_playtestBridgeTemplate: Instance?,
		_moduleFolder: Instance?,
	},
	{} :: typeof({ __index = ActionRouter })
))

function ActionRouter.new(): ActionRouter
	local self: ActionRouter = setmetatable({} :: any, ActionRouter)

	self._handlers = {}
	self._responseTypes = {}
	self._actions = {}
	self._failedActions = {}

	self._vendorPng = nil
	self._compiler = nil
	self._playtestBridgeTemplate = nil
	self._moduleFolder = nil

	return self
end

function ActionRouter.register(self: ActionRouter, messageType: string, handler: Handler)
	self._handlers[messageType] = handler
end

function ActionRouter.setResponseType(self: ActionRouter, messageType: string, responseType: string)
	self._responseTypes[messageType] = responseType
end

function ActionRouter.SetVendorPng(self: ActionRouter, png: any)
	self._vendorPng = png
end

function ActionRouter.SetPlaytestBridgeTemplate(self: ActionRouter, template: Instance)
	self._playtestBridgeTemplate = template
end

function ActionRouter.GetPlaytestBridgeTemplate(self: ActionRouter): Instance?
	return self._playtestBridgeTemplate
end

function ActionRouter.SetModuleFolder(self: ActionRouter, folder: Instance)
	self._moduleFolder = folder
end

function ActionRouter.GetModuleFolder(self: ActionRouter): Instance
	local folder = self._moduleFolder
	if folder then
		return folder
	end

	local created = Instance.new("Folder")
	created.Name = "Pushed"
	self._moduleFolder = created
	return created
end

function ActionRouter.SetCompiler(self: ActionRouter, compiler: Compiler)
	self._compiler = compiler
end

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

	if result.success == false and type(result.code) == "string" and type(result.message) == "string" then
		return ActionRouter._errorResponse(message, result.code, result.message, result.details)
	end

	return {
		type = self._responseTypes[message.type] or `{message.type}Result`,
		sessionId = message.sessionId,
		requestId = message.requestId,
		payload = result,
	}
end

function ActionRouter.Destroy(self: ActionRouter)
	for _, action in self._actions do
		if type(action.module) == "table" and type(action.module.teardown) == "function" then
			pcall(action.module.teardown)
		end
	end

	table.clear(self._actions)
	table.clear(self._failedActions)
	table.clear(self._handlers)
	table.clear(self._responseTypes)
end

function ActionRouter.Compile(self: ActionRouter, source: string, chunkName: string?): (any, string?)
	local loadstringOk, fn, compileErr = pcall(loadstring :: any, source, chunkName)
	if loadstringOk then
		return fn, compileErr
	end

	if self._compiler then
		return self._compiler(source, chunkName)
	end
	return ActionRouter._compileWithModuleScript(source, chunkName)
end

function ActionRouter._compileWithModuleScript(source: string, chunkName: string?): (any, string?)
	local moduleName = if chunkName then string.gsub(chunkName, "^[@=]", "") else "compiled"

	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Name = moduleName
	moduleScript.Source = `return function(...) {source}\nend`

	local requireOk, result = ActionRouter._requireModuleScript(moduleScript)
	moduleScript:Destroy()

	if requireOk then
		return result, nil
	end
	return nil, result
end

function ActionRouter._requireModuleScript(moduleScript: ModuleScript): (boolean, any)
	local fullName = moduleScript:GetFullName()
	local loadErrors: { string } = {}
	local logConnection = game:GetService("LogService").MessageOut:Connect(function(message, messageType)
		if messageType == Enum.MessageType.MessageError and string.find(message, fullName, 1, true) == 1 then
			table.insert(loadErrors, message)
		end
	end)

	local requireOk, result = pcall(require, moduleScript)
	if not requireOk then
		task.wait()
	end

	logConnection:Disconnect()

	if requireOk then
		return true, result
	end
	return false, loadErrors[1] or tostring(result)
end

function ActionRouter._installModule(
	self: ActionRouter,
	name: string,
	source: string,
	hash: string?
): (boolean, any, string?)
	local folder = self:GetModuleFolder()
	local existing = folder:FindFirstChild(name)
	if hash and existing and existing:IsA("ModuleScript") and existing:GetAttribute("Hash") == hash then
		return ActionRouter._requireModuleScript(existing)
	end

	local moduleScript = Instance.new("ModuleScript")
	moduleScript.Name = name
	local sourceOk = pcall(function()
		moduleScript.Source = source
	end)
	if not sourceOk then
		moduleScript:Destroy()
		if existing and existing:IsA("ModuleScript") then
			local requireOk, result = ActionRouter._requireModuleScript(existing)
			if requireOk then
				local plantedHash = existing:GetAttribute("Hash")
				return true, result, if type(plantedHash) == "string" then plantedHash else "planted"
			end
		end
		return false, PLANTED_ONLY_MESSAGE
	end
	if hash then
		moduleScript:SetAttribute("Hash", hash)
	end

	if existing then
		existing.Name = `{name}_Previous`
	end
	moduleScript.Parent = folder

	if folder.Parent and not folder:FindFirstChild("loader") then
		folder:WaitForChild("loader", 1)
	end

	local requireOk, result = ActionRouter._requireModuleScript(moduleScript)
	if requireOk then
		if existing then
			existing:Destroy()
		end
	else
		moduleScript:Destroy()
		if existing then
			existing.Name = name
		end

		local loadstringOk, fn, compileErr = pcall(loadstring :: any, source, `={name}`)
		if loadstringOk and not fn and compileErr then
			return false, compileErr
		end
	end
	return requireOk, result
end

function ActionRouter._errorResponse(message: Message, code: string, errorMessage: string, details: any?): Message
	return {
		type = "error",
		sessionId = message.sessionId,
		requestId = message.requestId,
		payload = {
			code = code,
			message = errorMessage,
			details = details,
		},
	}
end

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

	local ok, err = self:_replaceAction(name, source, sendMessage, logBuffer, responseType, hash, oldAction)
	if hash then
		self._failedActions[name] = if ok then nil else { hash = hash, error = err or "" }
	end
	return ok, err
end

function ActionRouter._replaceAction(
	self: ActionRouter,
	name: string,
	source: string,
	sendMessage: SendMessage?,
	logBuffer: any?,
	responseType: string?,
	hash: string?,
	oldAction: ActionInfo?
): (boolean, string?)
	local loadOk, moduleOrErr, plantedHash = self:_installModule(name, source, hash)
	if not loadOk then
		return false, `Failed to load action module: {moduleOrErr}`
	end
	local outdatedMessage = if plantedHash
		then `Failed to load action module: {PLANTED_ONLY_MESSAGE} It runs the version planted when the playtest started.`
		else nil
	if outdatedMessage and oldAction then
		return false, outdatedMessage
	end
	if type(moduleOrErr) ~= "table" and type(moduleOrErr) ~= "function" then
		return false, "Action module must return a table or a function"
	end

	local previousHandlers = table.clone(self._handlers)
	local previousResponseTypes = table.clone(self._responseTypes)
	if oldAction then
		for _, handlerName in oldAction.handlerNames do
			self._handlers[handlerName] = nil
			self._responseTypes[handlerName] = nil
		end
	end

	local handlersBefore: { [string]: boolean } = {}
	for handlerName in self._handlers do
		handlersBefore[handlerName] = true
	end

	if type(moduleOrErr) == "function" then
		self:register(name, moduleOrErr)
	elseif type(moduleOrErr.register) == "function" then
		local registerOk, registerErr = pcall(moduleOrErr.register, self, sendMessage, logBuffer)
		if not registerOk then
			self._handlers = previousHandlers
			self._responseTypes = previousResponseTypes
			if type(moduleOrErr.teardown) == "function" then
				pcall(moduleOrErr.teardown)
			end
			return false, `register() failed: {registerErr}`
		end
	end

	if oldAction and type(oldAction.module) == "table" and type(oldAction.module.teardown) == "function" then
		pcall(oldAction.module.teardown)
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

	local installedHash = plantedHash or hash
	if installedHash then
		self._actions[name] = {
			module = moduleOrErr,
			hash = installedHash,
			handlerNames = handlerNames,
		}
	end

	if outdatedMessage then
		return false, outdatedMessage
	end
	return true, nil
end

function ActionRouter.GetActionHandlerNames(self: ActionRouter, name: string): { string }?
	local action = self._actions[name]
	if not action then
		return nil
	end

	return table.clone(action.handlerNames)
end

function ActionRouter.GetInstalledActions(self: ActionRouter): { [string]: string }
	local result: { [string]: string } = {}
	for name, action in self._actions do
		result[name] = action.hash
	end
	return result
end

function ActionRouter.GetFailedAction(self: ActionRouter, name: string): FailedAction?
	return self._failedActions[name]
end

return ActionRouter
