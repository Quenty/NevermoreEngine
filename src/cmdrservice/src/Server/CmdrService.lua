--[=[
	Bridge to https://eryn.io/Cmdr/

	Uses [PermissionService] to provide permissions.
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
		local providerPromise = self._permissionService:PromisePermissionProvider()
		if providerPromise:IsPending() then
			return "Still loading permissions"
		end

		local ok, provider = providerPromise:Yield()
		if not ok then
			return provider or "Failed to load permission provider"
		end

		if context.Group == "DefaultAdmin" and not provider:IsAdmin(context.Executor) then
			return "You don't have permission to run this command"
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

function CmdrService:__ExecuteCommand(id, ...)
	assert(type(id) == "string", "Bad serviceId")
	assert(self._cmdr, "Not initialized")

	local execute = self._executeData[id]
	if not execute then
		error(("[CmdrService] - No command definition for id %q"):format(tostring(id)))
	end

	return execute(...)
end

-- Global, but only intended for internal use
function CmdrService:__GetServiceFromId(id)
	assert(type(id) == "string", "Bad serviceId")

	return GLOBAL_REGISTRY[id]
end

return CmdrService