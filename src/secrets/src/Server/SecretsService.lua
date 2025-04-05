--[=[
	@class SecretsService
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local SecretsServiceConstants = require("SecretsServiceConstants")
local GetRemoteFunction = require("GetRemoteFunction")
local Promise = require("Promise")
local Observable = require("Observable")
local EllipticCurveCryptography = require("EllipticCurveCryptography")
local _ServiceBag = require("ServiceBag")

local SecretsService = {}
SecretsService.ServiceName = "SecretsService"

function SecretsService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("CmdrService"))
	self._gameDataStoreService = self._serviceBag:GetService(require("GameDataStoreService"))
	self._permissionsService = self._serviceBag:GetService(require("PermissionService"))

	if not self._publicKey then
		-- Encryption at rest. Not really secure but if the public key seed is not set
		self:SetPublicKeySeed(game.GameId)
		self._warningRequired = true
	end

	-- Internal
	self._serviceBag:GetService(require("SecretsCommandService"))
end

--[=[
	Sets the public key seed for the cryptography-at-rest scenario

	@param seed number
]=]
function SecretsService:SetPublicKeySeed(seed: number)
	assert(type(seed) == "number", "Bad seed")

	local private, public = EllipticCurveCryptography.keypair(seed or EllipticCurveCryptography.random.random())
	self._publicKey = public
	self._privateKey = private
	self._warningRequired = false
end

--[=[
	Starts the secret service. Should be done via [ServiceBag].
]=]
function SecretsService:Start()
	self._remoteFunction = GetRemoteFunction(SecretsServiceConstants.REMOTE_FUNCTION_NAME)
	self._remoteFunction.OnServerInvoke = function(...)
		return self:_handleServerInvoke(...)
	end
end

--[=[
	Promises a secret value

	@param secretKey string
	@return Promise<string>
]=]
function SecretsService:PromiseSecret(secretKey: string)
	assert(type(secretKey) == "string", "Bad secretKey")

	return self:_promiseSubstore():Then(function(substore)
		return self._maid:GivePromise(substore:Load(secretKey)):Then(function(data)
			if type(data) ~= "table" then
				return Promise.resolved(nil)
			else
				local ok, value = self:_decrypt(data)
				if ok then
					return value
				else
					return Promise.rejected(value or "Failed to decrypt result")
				end
			end
		end)
	end)
end

--[=[
	Promises all secret values

	@return @return Promise<{string}>
]=]
function SecretsService:PromiseAllSecrets(): Promise.Promise<{ string }>
	return self:_promiseSubstore():Then(function(substore)
		return self._maid:GivePromise(substore:LoadAll()):Then(function(secretsList)
			local secretMap = {}

			for key, secretData in secretsList do
				local ok, decrypted = self:_decrypt(secretData)
				if ok then
					secretMap[key] = decrypted
				else
					warn(string.format("[SecretsService] - Failed to decrypt %q", key))
				end
			end

			return secretMap
		end)
	end)
end

--[=[
	Observes a secret value

	@param secretKey string
	@return Observable<string>
]=]
function SecretsService:ObserveSecret(secretKey: string): Observable.Observable<string>
	assert(type(secretKey) == "string", "Bad secretKey")

	return Observable.new(function(sub)
		local maid = Maid.new()

		maid:GivePromise(self:_promiseSubstore():Then(function(substore)
			maid:GivePromise(
				substore:Observe(secretKey):Subscribe(function(data)
					if type(data) ~= "table" then
						sub:Fire(nil)
					else
						local ok, value = self:_decrypt(data)
						if ok then
							sub:Fire(value)
						else
							-- TODO: Maybe brio instead?
							sub:Fail(value or "Failed to decrypt result")
						end
					end
				end),
				sub:GetFailComplete()
			)
		end, function(err)
			sub:Fail(err or "Failed to get datastore")
		end))

		return maid
	end)
end

--[=[
	Deletes a secret from the secret store

	@param secretKey string
]=]
function SecretsService:DeleteSecret(secretKey: string): Promise.Promise<()>
	assert(type(secretKey) == "string", "Bad secretKey")

	return self:_promiseSubstore():Then(function(substore)
		substore:Delete(secretKey)
	end)
end

--[=[
	Stores a secret in the secret store

	@param secretKey string
	@param value string
]=]
function SecretsService:StoreSecret(secretKey: string, value: string)
	assert(type(secretKey) == "string", "Bad secretKey")
	assert(type(value) == "string", "Bad value")

	self:_warnAboutNoPublicKeyStoredInSourceCode()

	self:_promiseSubstore():Then(function(substore)
		local encrypted = EllipticCurveCryptography.encrypt(value, self._privateKey)
		local signature = EllipticCurveCryptography.sign(self._privateKey, value)

		-- TODO: Encode byte array in more efficient structure for JSON
		local toStore = {
			encrypted = setmetatable(table.clone(encrypted), nil), -- remove metatable
			signature = setmetatable(table.clone(signature), nil), -- remove metatable
		}

		substore:Store(secretKey, toStore)
	end)
end

--[=[
	Clears all the secrets stored in the datastore

	@return Promise<()>
]=]
function SecretsService:ClearAllSecrets(): Promise.Promise<()>
	return self:_promiseSubstore():Then(function(substore)
		return substore:Wipe()
	end)
end

--[=[
	Gets a list of all available secret keys for the game

	@return Promise<{ string }>
]=]
function SecretsService:PromiseSecretKeyNamesList(): Promise.Promise<{ string }>
	return self:_promiseSubstore():Then(function(substore)
		return substore:PromiseKeyList()
	end)
end

function SecretsService:_warnAboutNoPublicKeyStoredInSourceCode()
	if self._warningRequired then
		self._warningRequired = false
		warn(self:_getInstructions())
	end
end

function SecretsService:_getInstructions(): string
	local instructions =
		"[SecretsService.StoreSecret] - Security - Current private key seed is GameId, which is guessable."
	instructions = instructions .. "\n\tTIP: This is only applicable if we're storing API keys for use in here."
	instructions = instructions
		.. "\n\tTIP: If you set the private key seed in source code, attackers need source code AND datastore access"
	instructions = instructions
		.. '\n\tTIP: Call `serviceBag:GetService(require("SecretsService")):SetPublicKeySeed(UNIQUE_RANDOM_NUMBER_HERE)` to suppress this warning.'
	instructions = instructions .. "\n\tTIP: This will invalidate previous secrets stored."
	return instructions
end

export type SecretsData = {
	encrypted: { number },
	signature: { number },
}

function SecretsService:_decrypt(data: SecretsData): (boolean?, string)
	assert(type(data) == "table", "Bad data")
	assert(data.encrypted ~= nil, "Bad data.encrypted")
	assert(data.signature ~= nil, "Bad data.signature")

	local encrypted = EllipticCurveCryptography.createByteTable(data.encrypted)
	local signature = EllipticCurveCryptography.createByteTable(data.signature)
	local decrypted = EllipticCurveCryptography.decrypt(encrypted, self._privateKey)

	-- Check signature
	local isOk = EllipticCurveCryptography.verify(self._publicKey, decrypted, signature)
	if not isOk then
		return nil, "Secret is signed with old key. Please set secrets again."
	end

	return true, tostring(decrypted)
end

function SecretsService:_handleServerInvoke(player, request)
	if request == SecretsServiceConstants.REQUEST_SECRET_KEY_NAMES_LIST then
		return self:_promiseHandleList(player):Yield()
	else
		error(string.format("Bad request %q", tostring(request)))
	end
end

function SecretsService:_promiseHandleList(player)
	return self._permissionsService:PromisePermissionProvider()
		:Then(function(provider)
			return provider:PromiseIsAdmin(player)
		end)
		:Then(function(isAdmin)
			if not isAdmin then
				return Promise.rejected("Not authorized")
			end

			return self:PromiseSecretKeyNamesList()
		end)
end

function SecretsService:_promiseSubstore()
	if self._substorePromise then
		return self._substorePromise
	end

	self._substorePromise = self._maid:GivePromise(self._gameDataStoreService:PromiseDataStore())
		:Then(function(dataStore)
			return dataStore:GetSubStore("secrets")
		end)

	return self._substorePromise
end

function SecretsService:Destroy()
	self._maid:DoCleaning()
end

return SecretsService