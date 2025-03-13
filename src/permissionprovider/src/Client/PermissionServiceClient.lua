--[=[
	Provides permissions on the client. See [PermissionService] for more details.

	:::tip
	Be sure to initialize the [PermissionService] on the server.
	:::

	@class PermissionServiceClient
	@client
]=]

local require = require(script.Parent.loader).load(script)

local PermissionProviderConstants = require("PermissionProviderConstants")
local PermissionProviderClient = require("PermissionProviderClient")
local Promise = require("Promise")
local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local PermissionServiceClient = {}
PermissionServiceClient.ServiceName = "PermissionServiceClient"

--[=[
	Initializes the permission service on the client. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function PermissionServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "no serviceBag")
	self._maid = Maid.new()

	self._providerPromise =
		Promise.resolved(PermissionProviderClient.new(PermissionProviderConstants.DEFAULT_REMOTE_FUNCTION_NAME))
end

--[=[
	Returns whether the player is an admin.

	@param player Player | nil
	@return Promise<boolean>
]=]
function PermissionServiceClient:PromiseIsAdmin(player: Player?)
	assert((typeof(player) == "Instance" and player:IsA("Player")) or player == nil, "Bad player")

	return self:PromisePermissionProvider():Then(function(permissionProvider)
		return permissionProvider:PromiseIsAdmin(player)
	end)
end

--[=[
	Returns the permission provider
	@return Promise<PermissionProviderClient>
]=]
function PermissionServiceClient:PromisePermissionProvider()
	return self._providerPromise
end

function PermissionServiceClient:Destroy()
	self._maid:DoCleaning()
end

return PermissionServiceClient
