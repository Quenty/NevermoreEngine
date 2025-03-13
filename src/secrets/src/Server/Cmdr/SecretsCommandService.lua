--[=[
	@class SecretsCommandService
]=]

local require = require(script.Parent.loader).load(script)

local SecretsCmdrTypeUtils = require("SecretsCmdrTypeUtils")
local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local SecretsCommandService = {}
SecretsCommandService.ServiceName = "SecretsCommandService"

function SecretsCommandService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._cmdrService = self._serviceBag:GetService(require("CmdrService"))
	self._secretsService = self._serviceBag:GetService((require :: any)("SecretsService"))
end

function SecretsCommandService:Start()
	self:_registerCommands()
end

function SecretsCommandService:_registerCommands()
	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function(cmdr)
		SecretsCmdrTypeUtils.registerSecretKeyTypes(cmdr, self._secretsService)
	end)

	self._cmdrService:RegisterCommand({
		Name = "list-all-secret-keys";
		Aliases = { };
		Description = "Lists all secret keys available.";
		Group = "Secrets";
		Args = {};
	}, function(_context)
		local secrets = self._secretsService:PromiseSecretKeyNamesList():Wait()

		local output = "SECRET KEYS"
		output = output .. "\n-----------"
		output = output .. "\n" .. table.concat(secrets, "\n")
		output = output .. "\n-----------"

		return output
	end)

	self._cmdrService:RegisterCommand({
		Name = "store-secret";
		Aliases = { };
		Description = "Stores a secret key.";
		Group = "Secrets";
		Args = {
			{
				Name = "SecretKey";
				Type = "secretKey";
				Description = "The key of the secret to store.";
			},
			{
				Name = "SecretValue";
				Type = "string";
				Description = "The value of the secret to store";
			}
		};
	}, function(_context, secretKey, secretValue)
		self._secretsService:StoreSecret(secretKey, secretValue)

		return string.format("Stored the secret for key %q", secretKey)
	end)

	self._cmdrService:RegisterCommand({
		Name = "delete-secret";
		Aliases = { };
		Description = "Stores a secret by key.";
		Group = "Secrets";
		Args = {
			{
				Name = "SecretKey";
				Type = "requiredSecretKey";
				Description = "The key of the secret to store.";
			}
		};
	}, function(_context, secretKey)
		self._secretsService:DeleteSecret(secretKey)

		return string.format("Deleted the secret for key %q", secretKey)
	end)

	self._cmdrService:RegisterCommand({
		Name = "read-secret";
		Aliases = { };
		Description = "Reads a secret by key.";
		Group = "Secrets";
		Args = {
			{
				Name = "SecretKey";
				Type = "requiredSecretKey";
				Description = "The key of the secret to read.";
			}
		};
	}, function(_context, secretKey)
		local secret = self._secretsService:PromiseSecret(secretKey):Wait()

		if secret then
			return secret
		else
			return "<no value>"
		end
	end)

	self._cmdrService:RegisterCommand({
		Name = "list-all-secrets";
		Aliases = { };
		Description = "Reads all secrets.";
		Group = "Secrets";
		Args = {};
	}, function(_context)
		local secrets = self._secretsService:PromiseAllSecrets():Wait()

		if not (secrets and next(secrets)) then
			return "<no secrets>"
		end

		local maxKeyLength = 6
		local maxValueLength = 5
		for key, value in secrets do
			maxKeyLength = math.max(maxKeyLength, #key)
			maxValueLength = math.max(maxValueLength, #value)
		end

		local output = string.format("\n%-" .. maxKeyLength .. "s %-" .. maxValueLength .. "s", "Secret", "Value")
		output = output .. string.format("\n%s %s", string.rep("-", maxKeyLength), string.rep("-", maxValueLength))
		for key, value in secrets do
			output = output .. string.format("\n%-" .. maxKeyLength .. "s %-" .. maxValueLength .. "s", key, value)
		end
		output = output .. string.format("\n%s %s", string.rep("-", maxKeyLength), string.rep("-", maxValueLength))

		return output
	end)

	self._cmdrService:RegisterCommand({
		Name = "clear-all-secrets";
		Aliases = { };
		Description = "Clears all secrets in the store.";
		Group = "Secrets";
		Args = {};
	}, function(_context)
		self._secretsService:ClearAllSecrets()

		return "Cleared all the secret in the store"
	end)
end

function SecretsCommandService:Destroy()
	self._maid:DoCleaning()
end

return SecretsCommandService