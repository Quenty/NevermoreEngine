--[=[
	Bridge to https://eryn.io/Cmdr/

	Uses [PermissionService] to provide permissions.
	@server
	@class CmdrService
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local CmdrTemplateProviderServer = require("CmdrTemplateProviderServer")
local Promise = require("Promise")
local Maid = require("Maid")
local PermissionService = require("PermissionService")
local _ServiceBag = require("ServiceBag")
local _CmdrTypes = require("CmdrTypes")

local CmdrService = {}
CmdrService.ServiceName = "CmdrService"

export type CmdrService = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_serviceBag: _ServiceBag.ServiceBag,
		_serviceId: string,
		_promiseCmdr: Promise.Promise<any>,
		_cmdrTemplateProviderServer: any,
		_permissionService: PermissionService.PermissionService,
		_definitionData: { [string]: _CmdrTypes.CommandDefinition },
		_executeData: { [string]: (context: _CmdrTypes.CommandContext, ...any) -> string? },
	},
	{} :: typeof({ __index = CmdrService })
))

local GLOBAL_REGISTRY = setmetatable({}, { __mode = "kv" })

--[=[
	Initializes the CmdrService. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function CmdrService.Init(self: CmdrService, serviceBag: _ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._maid = Maid.new()
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._permissionService = self._serviceBag:GetService(PermissionService)

	-- Internal
	self._cmdrTemplateProviderServer = self._serviceBag:GetService(CmdrTemplateProviderServer)

	self._serviceId = HttpService:GenerateGUID(false)
	self._promiseCmdr = self._maid:GivePromise(Promise.spawn(function(resolve, reject)
		if not RunService:IsRunning() then
			reject() -- Avoid running when game isn't available
			return
		end

		local cmdr
		local ok, err = pcall(function()
			cmdr = require("Cmdr")
		end)
		if not ok then
			reject(err or "Failed to load cmdr")
			return
		end
		resolve(cmdr)
	end))

	self._definitionData = {}
	self._executeData = {}

	self._promiseCmdr:Then(function(cmdr)
		task.spawn(function()
			cmdr:RegisterDefaultCommands()
		end)

		cmdr.Registry:RegisterHook("BeforeRun", function(context)
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
	end)

	GLOBAL_REGISTRY[self._serviceId] = self
end

--[=[
	Returns cmdr
	@return Promise<Cmdr>
]=]
function CmdrService.PromiseCmdr(self: CmdrService)
	assert(self._promiseCmdr, "Not initialized")

	return self._promiseCmdr
end

--[=[
	Registers a command into cmdr.
	@param commandData table
	@param execute (context: table, ... T)
]=]
function CmdrService.RegisterCommand(
	self: CmdrService,
	commandData: _CmdrTypes.CommandDefinition,
	execute: (context: _CmdrTypes.CommandContext, ...any) -> string?
): ()
	assert((self :: any)._promiseCmdr, "Not initialized")
	assert(commandData, "No commandData")
	assert(commandData.Name, "No commandData.Name")
	assert(execute, "No execute")

	local commandId = string.format("%s_%s", commandData.Name, HttpService:GenerateGUID(false))

	self._definitionData[commandId] = commandData
	self._executeData[commandId] = execute

	local commandServerScript = self._cmdrTemplateProviderServer:Clone("CmdrExecutionTemplate")
	commandServerScript.Name = string.format("%sServer", commandId)

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

	self._promiseCmdr:Then(function(cmdr)
		cmdr.Registry:RegisterCommand(commandScript, commandServerScript)
	end)
end

--[=[
	Private function used by the execution template to retrieve the execution function.
	@param cmdrCommandId string
	@param ... any
	@private
]=]
function CmdrService.__executeCommand(self: CmdrService, cmdrCommandId: string, ...): string?
	assert(type(cmdrCommandId) == "string", "Bad cmdrCommandId")
	assert(self._promiseCmdr, "CmdrService is not initialized yet")

	local execute = self._executeData[cmdrCommandId]
	if not execute then
		error(string.format("[CmdrService] - No command definition for cmdrCommandId %q", tostring(cmdrCommandId)))
	end

	return execute(...)
end

--[=[
	Global usage but only intended for internal use

	@param cmdrServiceId string
	@return CmdrService
	@private
]=]
function CmdrService.__getServiceFromId(_self: CmdrService, cmdrServiceId: string)
	assert(type(cmdrServiceId) == "string", "Bad cmdrServiceId")

	return GLOBAL_REGISTRY[cmdrServiceId]
end

function CmdrService.Destroy(self: CmdrService)
	self._maid:DoCleaning()
end

return CmdrService