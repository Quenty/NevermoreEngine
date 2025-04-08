--[=[
	Provides permissions for the game. See [BasePermissionProvider].

	:::tip
	Be sure to initialize the [PermissionServiceClient] on the client.
	:::

	```lua
	local require = require(script.Parent.loader).load(script)

	local PermissionProvider = require("PermissionProvider")
	local PermissionProviderUtils = require("PermissionProviderUtils")

	return PermissionProvider.new(PermissionProviderUtils.createGroupRankConfig({
	  groupId = 8668163;
	  minAdminRequiredRank = 250;
	  minCreatorRequiredRank = 254;
	}))
	```

	@server
	@class PermissionService
]=]

local require = require(script.Parent.loader).load(script)

local CreatorPermissionProvider = require("CreatorPermissionProvider")
local GroupPermissionProvider = require("GroupPermissionProvider")
local Maid = require("Maid")
local PermissionLevel = require("PermissionLevel")
local PermissionProviderConstants = require("PermissionProviderConstants")
local PermissionProviderUtils = require("PermissionProviderUtils")
local Promise = require("Promise")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxPlayerUtils = require("RxPlayerUtils")
local PermissionLevelUtils = require("PermissionLevelUtils")
local _ServiceBag = require("ServiceBag")
local _Observable = require("Observable")
local _Brio = require("Brio")
local _BasePermissionProvider = require("BasePermissionProvider")

local PermissionService = {}
PermissionService.ServiceName = "PermissionService"

export type PermissionService = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_promise: Promise.Promise<()>,
		_provider: any,
	},
	{} :: typeof({ __index = PermissionService })
))

--[=[
	Initializes the service. Should be done via [ServiceBag].
	@param _serviceBag ServiceBag
]=]
function PermissionService:Init(_serviceBag: _ServiceBag.ServiceBag)
	assert(not self._promise, "Already initialized")
	assert(not self._provider, "Already have provider")

	self._provider = nil
	self._maid = Maid.new()
	self._promise = self._maid:Add(Promise.new())
end

--[=[
	Sets the provider from a config. See [PermissionProviderUtils.createGroupRankConfig]
	and [PermissionProviderUtils.createSingleUserConfig].

	@param config { type: string }
]=]
function PermissionService:SetProviderFromConfig(config: PermissionProviderUtils.PermissionProviderConfig)
	assert(self._promise, "Not initialized")
	assert(not self._provider, "Already have provider set")

	if config.type == PermissionProviderConstants.GROUP_RANK_CONFIG_TYPE then
		self._provider = GroupPermissionProvider.new(config)
	elseif config.type == PermissionProviderConstants.SINGLE_USER_CONFIG_TYPE then
		self._provider = CreatorPermissionProvider.new(config)
	else
		error("Bad provider")
	end
end

--[=[
	Starts the permission service. Should be done via [ServiceBag].
]=]
function PermissionService:Start()
	if not self._provider then
		self:SetProviderFromConfig(PermissionProviderUtils.createConfigFromGame())
	end

	self._provider:Start()

	self._promise:Resolve(self._provider)
end

--[=[
	Returns the permission provider
	@return Promise<BasePermissionProvider>
]=]
function PermissionService:PromisePermissionProvider(): Promise.Promise<_BasePermissionProvider.BasePermissionProvider>
	assert(self._promise, "Not initialized")

	return self._promise
end

--[=[
	Returns whether the player is an admin.
	@param player Player
	@return Promise<boolean>
]=]
function PermissionService:PromiseIsAdmin(player: Player): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "bad player")

	return self:PromiseIsPermissionLevel(player, PermissionLevel.ADMIN)
end

--[=[
	Returns whether the player is a creator.
	@param player Player
	@return Promise<boolean>
]=]
function PermissionService:PromiseIsCreator(player: Player): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "bad player")

	return self:PromiseIsPermissionLevel(player, PermissionLevel.CREATOR)
end

--[=[
	Returns whether the player is a creator.
	@param player Player
	@param permissionLevel PermissionLevel
	@return Promise<boolean>
]=]
function PermissionService:PromiseIsPermissionLevel(
	player: Player,
	permissionLevel: PermissionLevel.PermissionLevel
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "bad player")
	assert(PermissionLevelUtils.isPermissionLevel(permissionLevel), "Bad permissionLevel")

	return self:PromisePermissionProvider():Then(function(permissionProvider)
		return permissionProvider:PromiseIsPermissionLevel(player, permissionLevel)
	end)
end

--[=[
	Observe all creators in the game

	@param permissionLevel PermissionLevel
	@return Observable<Brio<Player>>
]=]
function PermissionService:ObservePermissionedPlayersBrio(permissionLevel: PermissionLevel.PermissionLevel): _Observable.Observable<_Brio.Brio<Player>>
	assert(PermissionLevelUtils.isPermissionLevel(permissionLevel), "Bad permissionLevel")

	return RxPlayerUtils.observePlayersBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(player)
			return Rx.fromPromise(self:PromiseIsPermissionLevel(player, permissionLevel)):Pipe({
				Rx.switchMap(function(hasPermission)
					if hasPermission then
						return Rx.of(player)
					else
						return Rx.EMPTY
					end
				end),
			})
		end),
	})
end

function PermissionService:Destroy()
	self._maid:DoCleaning()
	self._provider = nil
end

return PermissionService
