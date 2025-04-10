--!strict
--[=[
	@class GameProductDataService
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local Maid = require("Maid")
local PlayerProductManagerInterface = require("PlayerProductManagerInterface")
local Promise = require("Promise")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local Signal = require("Signal")
local TieRealmService = require("TieRealmService")
local _ServiceBag = require("ServiceBag")
local _Observable = require("Observable")
local _Brio = require("Brio")

local GameProductDataService = {}
GameProductDataService.ServiceName = "GameProductDataService"

export type GameProductDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: _ServiceBag.ServiceBag,
		_tieRealmService: TieRealmService.TieRealmService,
		_maid: Maid.Maid,

		GamePassPurchased: Signal.Signal<Player, number>,
		ProductPurchased: Signal.Signal<Player, number>,
		AssetPurchased: Signal.Signal<Player, number>,
		BundlePurchased: Signal.Signal<Player, number>,
		MembershipPurchased: Signal.Signal<Player, number>,
		SubscriptionPurchased: Signal.Signal<Player, number>,
	},
	{} :: typeof({ __index = GameProductDataService })
))

function GameProductDataService.Init(self: GameProductDataService, serviceBag: _ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._tieRealmService = self._serviceBag:GetService(TieRealmService) :: any

	self._maid = Maid.new()

	-- Configure
	self.GamePassPurchased = self._maid:Add(Signal.new() :: any) -- :Fire(player, gamePassId)
	self.ProductPurchased = self._maid:Add(Signal.new() :: any) -- :Fire(player, productId)
	self.AssetPurchased = self._maid:Add(Signal.new() :: any) -- :Fire(player, assetId)
	self.BundlePurchased = self._maid:Add(Signal.new() :: any) -- :Fire(player, bundleId)
	self.SubscriptionPurchased = self._maid:Add(Signal.new() :: any) -- :Fire(player, subscriptionId)
	self.MembershipPurchased = self._maid:Add(Signal.new() :: any) -- :Fire(player, membershipId)
end

--[=[
	Starts the service. Should be done via [ServiceBag]
]=]
function GameProductDataService.Start(self: GameProductDataService)
	self._maid:GiveTask(
		PlayerProductManagerInterface:ObserveAllTaggedBrio("PlayerProductManager", self._tieRealmService:GetTieRealm())
			:Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				local maid, playerProductManager = brio:ToMaidAndValue()

				local function exportSignal(signal, assetType)
					maid:GiveTask(playerProductManager:GetAssetTrackerOrError(assetType).Purchased:Connect(function(...)
						signal:Fire(playerProductManager:GetPlayer(), ...)
					end))
				end

				exportSignal(self.GamePassPurchased, GameConfigAssetTypes.PASS)
				exportSignal(self.ProductPurchased, GameConfigAssetTypes.PRODUCT)
				exportSignal(self.AssetPurchased, GameConfigAssetTypes.ASSET)
				exportSignal(self.BundlePurchased, GameConfigAssetTypes.BUNDLE)
				exportSignal(self.SubscriptionPurchased, GameConfigAssetTypes.SUBSCRIPTION)
				exportSignal(self.MembershipPurchased, GameConfigAssetTypes.MEMBERSHIP)
			end)
	)
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return boolean
]=]
function GameProductDataService.HasPlayerPurchasedThisSession(
	self: GameProductDataService,
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): boolean
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	local playerProductManager = self:_getPlayerProductManager(player)
	if not playerProductManager then
		warn("[GameProductDataService.HasPlayerPurchasedThisSession] - Failed to find playerProductManager for player")
		return false
	end

	local assetTracker = playerProductManager:GetAssetTrackerOrError(assetType)
	return assetTracker:HasPurchasedThisSession(idOrKey)
end

--[=[
	Prompts the user to purchase the asset, and returns true if purchased

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductDataService.PromisePromptPurchase(
	self: GameProductDataService,
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_promisePlayerProductManager(player):Then(function(playerProductManager)
		local assetTracker = playerProductManager:GetAssetTrackerOrError(assetType)
		return assetTracker:PromisePromptPurchase(idOrKey)
	end)
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductDataService.PromisePlayerOwnership(
	self: GameProductDataService,
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_promisePlayerProductManager(player):Then(function(playerProductManager)
		local ownershipTracker = playerProductManager:GetOwnershipTrackerOrError(assetType)
		return ownershipTracker:PromiseOwnsAsset(idOrKey)
	end)
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@return Promise<boolean>
]=]
function GameProductDataService.PromiseIsOwnable(
	self: GameProductDataService,
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	return self:_promisePlayerProductManager(player):Then(function(playerProductManager)
		return playerProductManager:IsOwnable(assetType)
	end)
end

--[=[
	Promises the player prompt as opened

	@param player Player
	@return Promise<boolean>
]=]
function GameProductDataService.PromisePlayerIsPromptOpen(
	self: GameProductDataService,
	player: Player
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:_promisePlayerProductManager(player):Then(function(playerProductManager)
		return playerProductManager:IsPromptOpen()
	end)
end

--[=[
	Promises the player prompt as opened

	@param player Player
	@return Promise<boolean>
]=]
function GameProductDataService.PromisePlayerPromptClosed(
	self: GameProductDataService,
	player: Player
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:_promisePlayerProductManager(player):Then(function(playerProductManager)
		return playerProductManager:PromisePlayerPromptClosed()
	end)
end

--[=[
	Observes player ownership

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<boolean>
]=]
function GameProductDataService.ObservePlayerOwnership(
	self: GameProductDataService,
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): _Observable.Observable<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	-- TODO: Maybe make this more light weight and cache
	return self:_observePlayerProductManagerBrio(player):Pipe({
		RxBrioUtils.flattenToValueAndNil :: any,
		Rx.switchMap(function(playerProductManager): any
			if playerProductManager then
				local ownershipTracker = playerProductManager:GetOwnershipTrackerOrError(assetType)
				return ownershipTracker:ObserveOwnsAsset(idOrKey)
			else
				return Rx.EMPTY
			end
		end) :: any,
	}) :: any
end

--[=[
	Fires when the specified player purchases an asset

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<>
]=]
function GameProductDataService.ObservePlayerAssetPurchased(
	self: GameProductDataService,
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): _Observable.Observable<()>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_observePlayerProductManagerBrio(player):Pipe({
		RxBrioUtils.flattenToValueAndNil,
		RxBrioUtils.switchMapBrio(function(playerProductManager): any
			if playerProductManager then
				local ownershipTracker = playerProductManager:GetOwnershipTrackerOrError(assetType)
				return ownershipTracker:ObserveAssetPurchased(idOrKey)
			else
				return Rx.EMPTY
			end
		end),
		Rx.map(function()
			return true
		end) :: any,
	}) :: any
end

--[=[
	Fires when any player purchases an asset

	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<Player>
]=]
function GameProductDataService.ObserveAssetPurchased(
	self: GameProductDataService,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return PlayerProductManagerInterface
		:ObserveAllTaggedBrio("PlayerProductManager", self._tieRealmService:GetTieRealm())
		:Pipe({
			RxBrioUtils.flatMapBrio(function(playerProductManager)
				local assetTracker = playerProductManager:GetAssetTrackerOrError(assetType)
				return assetTracker:ObserveAssetPurchased(idOrKey):Pipe({
					Rx.map(function()
						return playerProductManager:GetPlayer()
					end),
				})
			end),
			Rx.map(function(brio)
				-- I THINK THIS LEAKS
				if brio:IsDead() then
					return nil
				end

				return brio:GetValue()
			end),
			Rx.where(function(value)
				return value ~= nil
			end),
		})
end

--[=[
	Checks if the asset is ownable and if it is, checks player ownership. Otherwise, it checks if the asset
	has been purchased this session. If the asset has not been purchased this session it prompts the user to
	purchase the item.

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductDataService.PromisePlayerOwnershipOrPrompt(
	self: GameProductDataService,
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_promisePlayerProductManager(player):Then(function(playerProductManager)
		local assetTracker = playerProductManager:GetAssetTrackerOrError(assetType)

		if playerProductManager:IsOwnable(assetType) then
			-- Retrieve ownership
			local ownershipTracker = playerProductManager:GetOwnershipTrackerOrError(assetType)
			return ownershipTracker:PromiseOwnsAsset(idOrKey):Then(function(ownsAsset)
				if ownsAsset then
					return true
				else
					return assetTracker:PromisePromptPurchase(idOrKey)
				end
			end)
		else
			-- Assume this is a single session purchase
			if assetTracker:HasPurchasedThisSession(idOrKey) then
				return Promise.resolved(true)
			end

			return assetTracker:PromisePromptPurchase(idOrKey)
		end
	end)
end

function GameProductDataService._observePlayerProductManagerBrio(
	self: GameProductDataService,
	player: Player
): _Observable.Observable<_Brio.Brio<any>>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerProductManagerInterface:ObserveBrio(player, self._tieRealmService:GetTieRealm())
end

function GameProductDataService._promisePlayerProductManager(
	self: GameProductDataService,
	player: Player
): Promise.Promise<any>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerProductManagerInterface:Promise(player, self._tieRealmService:GetTieRealm())
end

function GameProductDataService._getPlayerProductManager(self: GameProductDataService, player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return PlayerProductManagerInterface:Find(player, self._tieRealmService:GetTieRealm())
end

function GameProductDataService.Destroy(self: GameProductDataService)
	self._maid:DoCleaning()
end

return GameProductDataService
