--[=[
	@class SecretsServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local PromiseGetRemoteFunction = require("PromiseGetRemoteFunction")
local SecretsCmdrTypeUtils = require("SecretsCmdrTypeUtils")
local SecretsServiceConstants = require("SecretsServiceConstants")
local RemoteFunctionUtils = require("RemoteFunctionUtils")
local Promise = require("Promise")
local _ServiceBag = require("ServiceBag")

local SecretsServiceClient = {}
SecretsServiceClient.ServiceName = "SecretsServiceClient"

function SecretsServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._cmdrService = self._serviceBag:GetService(require("CmdrServiceClient"))
	self._permissionsService = self._serviceBag:GetService(require("PermissionServiceClient"))
end

function SecretsServiceClient:Start()
	self:_registerCmdrTypes()
end

function SecretsServiceClient:PromiseSecretKeyNamesList()
	return self:_promiseRemoteFunction()
		:Then(function(remoteFunction)
			return self._maid:GivePromise(RemoteFunctionUtils.promiseInvokeServer(
				remoteFunction,
				SecretsServiceConstants.REQUEST_SECRET_KEY_NAMES_LIST))
		end)
		:Then(function(ok, list)
			if not ok then
				return Promise.rejected(list or "Failed to get list")
			else
				return Promise.resolved(list)
			end
		end)
end

function SecretsServiceClient:_registerCmdrTypes()
	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function(cmdr)
		SecretsCmdrTypeUtils.registerSecretKeyTypes(cmdr, self)
	end)
end

function SecretsServiceClient:_promiseRemoteFunction()
	if self._remoteFunctionPromise then
		return self._remoteFunctionPromise
	end

	self._remoteFunctionPromise = self._maid:GivePromise(PromiseGetRemoteFunction(SecretsServiceConstants.REMOTE_FUNCTION_NAME))
	return self._remoteFunctionPromise
end

function SecretsServiceClient:Destroy()
	self._maid:DoCleaning()
end

return SecretsServiceClient