--!strict
--[=[
	Provides permissions on the client. See [PermissionService] for more details.

	:::tip
	Be sure to initialize the [PermissionService] on the server.
	:::

	@class PermissionServiceClient
	@client
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local PermissionProviderClient = require("PermissionProviderClient")
local PermissionProviderConstants = require("PermissionProviderConstants")
local PlayerMock = require("PlayerMock")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local PermissionServiceClient = {}
PermissionServiceClient.ServiceName = "PermissionServiceClient"

export type PermissionServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_providerPromise: Promise.Promise<PermissionProviderClient.PermissionProviderClient>,
	},
	{} :: typeof({ __index = PermissionServiceClient })
))

--[=[
	Initializes the permission service on the client. Should be done via [ServiceBag].
	@param serviceBag ServiceBag
]=]
function PermissionServiceClient.Init(self: PermissionServiceClient, serviceBag: ServiceBag.ServiceBag): ()
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
function PermissionServiceClient.PromiseIsAdmin(
	self: PermissionServiceClient,
	player: Player?
): Promise.Promise<boolean>
	assert(
		(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player))) or player == nil,
		"Bad player"
	)

	return self:PromisePermissionProvider():Then(function(permissionProvider)
		return permissionProvider:PromiseIsAdmin(player)
	end)
end

--[=[
	Returns the permission provider
	@return Promise<PermissionProviderClient>
]=]
function PermissionServiceClient.PromisePermissionProvider(self: PermissionServiceClient): Promise.Promise<
	PermissionProviderClient.PermissionProviderClient
>
	return self._providerPromise
end

function PermissionServiceClient.Destroy(self: PermissionServiceClient): ()
	self._maid:DoCleaning()
end

return PermissionServiceClient
