--[=[
	Bridge to https://eryn.io/Cmdr/

	Uses [PermissionService] to provide permissions.
	@server
	@class CmdrService
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local PermissionService = require("PermissionService")
local CmdrTemplateProviderServer = require("CmdrTemplateProviderServer")
local Promise = require("Promise")

local CmdrService = {}

local GLOBAL_REGISTRY = setmetatable({}, {__mode = "kv"})

--[=[
	Initializes the CmdrService. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function CmdrService:Init(serviceBag)
	assert(not self._cmdr, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._cmdrTemplateProviderServer = self._serviceBag:GetService(CmdrTemplateProviderServer)

	self._serviceId = HttpService:GenerateGUID(false)
	self._cmdr = require("Cmdr")

	self._permissionService = serviceBag:GetService(PermissionService)

	self._definitionData = {}
	self._executeData = {}

	self._cmdr.Registry:RegisterHook("BeforeRun", function(context)
		-- allow!
		if context.Executor == nil then
			return nil
		end

		local providerPromise = self._permissionService:PromisePermissionProvider()
		if providerPromise:IsPending() then
			return "Still loading permissions"
		end

		local ok, provider = providerPromise:Yield()
		if not ok then
			if type(provider) == "string" then
				return provider
			else
				return "Failed to load permission provider"
			end
		end

		if not provider:IsAdmin(context.Executor) then
			return "You don't have permission to run this command"
		else
			-- allow
			return nil
		end
	end)

	GLOBAL_REGISTRY[self._serviceId] = self
end

--[=[
	Starts the service. Should be done via [ServiceBag]
]=]
function CmdrService:Start()
	self._cmdr:RegisterDefaultCommands()
end

--[=[
	Returns cmdr
	@return Promise<Cmdr>
]=]
function CmdrService:PromiseCmdr()
	assert(self._cmdr, "Not initialized")

	return Promise.resolved(self._cmdr)
end

--[=[
	Registers a command into cmdr.
	@param commandData table
	@param execute (context: table, ... T)
]=]
function CmdrService:RegisterCommand(commandData, execute)
	assert(self._cmdr, "Not initialized")
	assert(commandData, "No commandData")
	assert(commandData.Name, "No commandData.Name")
	assert(execute, "No execute")

	local commandId = ("%s_%s"):format(commandData.Name, HttpService:GenerateGUID(false))

	self._definitionData[commandId] = commandData
	self._executeData[commandId] = execute

	local commandServerScript = self._cmdrTemplateProviderServer:Clone("CmdrExecutionTemplate")
	commandServerScript.Name = ("%sServer"):format(commandId)

	local cmdrServiceTarget = Instance.new("ObjectValue")
	cmdrServiceTarget.Name = "CmdrServiceTarget"
	cmdrServiceTarget.Value = script
	cmdrServiceTarget.Parent = commandServerScript

	local cmdrServiceId = Instance.new("StringValue")
	cmdrServiceId.Name = "CmdrServiceId"
	cmdrServiceId.Value = self._serviceId
	cmdrServiceId.Parent = commandServerScript

	local cmdrCommandId = Instance.new("StringValue")
	cmdrCommandId.Name = "CmdrCommandId"
	cmdrCommandId.Value = commandId
	cmdrCommandId.Parent = commandServerScript

	local commandScript = self._cmdrTemplateProviderServer:Clone("CmdrCommandDefinitionTemplate")
	commandScript.Name = commandId

	local cmdrJsonCommandData = Instance.new("StringValue")
	cmdrJsonCommandData.Value = HttpService:JSONEncode(commandData)
	cmdrJsonCommandData.Name = "CmdrJsonCommandData"
	cmdrJsonCommandData.Parent = commandScript

	self._cmdr.Registry:RegisterCommand(commandScript, commandServerScript)
end

--[=[
	Private function used by the execution template to retrieve the execution function.
	@param cmdrCommandId string
	@param ... any
	@private
]=]
function CmdrService:__executeCommand(cmdrCommandId, ...)
	assert(type(cmdrCommandId) == "string", "Bad cmdrCommandId")
	assert(self._cmdr, "CmdrService is not initialized yet")

	local execute = self._executeData[cmdrCommandId]
	if not execute then
		error(("[CmdrService] - No command definition for cmdrCommandId %q"):format(tostring(cmdrCommandId)))
	end

	return execute(...)
end

--[=[
	Global usage but only intended for internal use

	@param cmdrServiceId string
	@return CmdrService
	@private
]=]
function CmdrService:__getServiceFromId(cmdrServiceId)
	assert(type(cmdrServiceId) == "string", "Bad cmdrServiceId")

	return GLOBAL_REGISTRY[cmdrServiceId]
end

return CmdrService