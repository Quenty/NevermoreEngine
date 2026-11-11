--!strict
--[=[
	@class GameProductDataService
]=]

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local PlayerProductManagerInterface = require("PlayerProductManagerInterface")
local Promise = require("Promise")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")
local RxBrioUtils = require("RxBrioUtils")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")
local ValueObject = require("ValueObject")

local GameProductDataService = {}
GameProductDataService.ServiceName = "GameProductDataService"

GameProductDataService.ServerOnlyPromptingAttribute = "GameProductServerOnlyPrompting"

export type GameProductDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_tieRealmService: TieRealmService.TieRealmService,
		_maid: Maid.Maid,
		_serverOnlyPrompting: ValueObject.ValueObject<boolean>,

		GamePassPurchased: Signal.Signal<Player, number>,
		ProductPurchased: Signal.Signal<Player, number>,
		AssetPurchased: Signal.Signal<Player, number>,
		BundlePurchased: Signal.Signal<Player, number>,
		MembershipPurchased: Signal.Signal<Player, number>,
		SubscriptionPurchased: Signal.Signal<Player, number>,
	},
	{} :: typeof({ __index = GameProductDataService })
))

function GameProductDataService.Init(self: GameProductDataService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._tieRealmService = self._serviceBag:GetService(TieRealmService) :: any

	self._maid = Maid.new()

	-- Source of truth for server-only prompting. On the server this is set via
	-- [GameProductService:SetServerOnlyPromptingEnabled] and replicated to clients
	-- through the PlayerProductManager tie. On the client we read the replicated
	-- value to decide whether to refuse local prompts.
	self._serverOnlyPrompting = self._maid:Add(ValueObject.new(false, "boolean"))

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
	Sets whether prompting is restricted to the server. When enabled, clients can no
	longer prompt purchases directly via [GameProductDataService:PromisePromptPurchase];
	prompts must be initiated from the server. Can only be set from the server.

	@param serverOnly boolean
]=]
function GameProductDataService.SetServerOnlyPrompting(self: GameProductDataService, serverOnly: boolean): ()
	assert(type(serverOnly) == "boolean", "Bad serverOnly")
	assert(
		self._tieRealmService:GetTieRealm() ~= TieRealms.CLIENT,
		"[GameProductDataService] - Server-only prompting can only be configured from the server"
	)

	self._serverOnlyPrompting.Value = serverOnly
end

--[=[
	Returns the server-authoritative server-only prompting [ValueObject]. This is
	exported through the PlayerProductManager tie so it replicates to clients.

	@return ValueObject<boolean>
]=]
function GameProductDataService.GetServerOnlyPromptingValue(
	self: GameProductDataService
): ValueObject.ValueObject<boolean>
	return self._serverOnlyPrompting
end

--[=[
	Returns true if server-only prompting is currently enabled. On the client this
	reads the value replicated from the server for the local player.

	@param player Player
	@return Observable<boolean>
]=]
function GameProductDataService.ObserveServerOnlyPrompting(
	_self: GameProductDataService,
	player: Player
): Observable.Observable<boolean>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")

	-- Always read the server-authoritative value (the server implementation), which
	-- replicates down to clients as an attribute on the PlayerProductManager folder.
	return RxAttributeUtils.observeAttribute(
			player,
			GameProductDataService.ServerOnlyPromptingAttribute,
			false
		)
			:Pipe({
				Rx.map(function(value: any)
					return value == true
				end) :: any,
				Rx.distinct() :: any,
			}) :: any
end

--[=[
	Resolves if the caller is allowed to prompt a purchase, rejecting if server-only
	prompting is enabled and we are on the client. The server is always authorized.

	@param player Player
	@return Promise
]=]
function GameProductDataService._promiseServerOnlyPromptingGuard(
	self: GameProductDataService,
	player: Player
): Promise.Promise<()>
	-- The server (and a single shared realm) is the authority and may always prompt.
	if self._tieRealmService:GetTieRealm() ~= TieRealms.CLIENT then
		return Promise.resolved()
	end

	return Rx.toPromise(self:ObserveServerOnlyPrompting(player) :: any):Then(function(serverOnly)
		if serverOnly then
			return Promise.rejected(
				"[GameProductDataService] - Server-only prompting is enabled. The client cannot prompt purchases "
					.. "directly; prompts must be initiated from the server."
			)
		end

		return nil
	end)
end

--[=[
	Applies the server-only prompting guard and then prompts the purchase. Used by all
	prompt entry points so the guard is enforced consistently.

	@param player Player
	@param assetTracker PlayerAssetMarketTracker
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductDataService._promiseGuardedPromptPurchase(
	self: GameProductDataService,
	player: Player,
	assetTracker: any,
	idOrKey: string | number
): Promise.Promise<boolean>
	return self:_promiseServerOnlyPromptingGuard(player):Then(function()
		return assetTracker:PromisePromptPurchase(idOrKey)
	end)
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
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")
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
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_promisePlayerProductManager(player):Then(function(playerProductManager)
		local assetTracker = playerProductManager:GetAssetTrackerOrError(assetType)
		return self:_promiseGuardedPromptPurchase(player, assetTracker, idOrKey)
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
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_promisePlayerProductManager(player):Then(function(playerProductManager)
		local ownershipTracker = playerProductManager:GetOwnershipTrackerOrError(assetType)
		return ownershipTracker:PromiseOwnsAsset(idOrKey)
	end)
end

--[=[
	Sets a server-authoritative override for the player's ownership of the asset. When set, the
	override wins over the cloud query and any session purchase, forcing ownership on (`true`) or off
	(`false`). Passing `nil` clears the override.

	The override is stored in a replicated attribute and applied to every realm's ownership tracker,
	so it drives client-side ownership-gated UI. It can only be set from the server: this rejects on
	the client realm, and [GameProductServiceClient] deliberately exposes no setter, so a player can
	never grant themselves ownership.

	@server
	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@param ownsAsset boolean?
	@return Promise
]=]
function GameProductDataService.SetPlayerOwnershipOverride(
	self: GameProductDataService,
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number,
	ownsAsset: boolean?
): Promise.Promise<()>
	-- Server authority: ownership overrides are never assignable from a client (otherwise a player
	-- could grant themselves ownership of paid assets).
	assert(
		self._tieRealmService:GetTieRealm() ~= TieRealms.CLIENT,
		"[GameProductDataService] - Ownership overrides can only be set from the server"
	)
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")
	assert(type(ownsAsset) == "boolean" or ownsAsset == nil, "Bad ownsAsset")

	return self:_promisePlayerProductManager(player):Then(function(playerProductManager)
		local ownershipTracker = playerProductManager:GetOwnershipTrackerOrError(assetType)
		ownershipTracker:SetOwnershipOverride(idOrKey, ownsAsset)
	end)
end

--[=[
	Clears any ownership override for the asset, so ownership falls back to the cloud query.
	Equivalent to `SetPlayerOwnershipOverride(player, assetType, idOrKey, nil)`, and likewise
	server-only.

	@server
	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise
]=]
function GameProductDataService.ClearPlayerOwnershipOverride(
	self: GameProductDataService,
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): Promise.Promise<()>
	return self:SetPlayerOwnershipOverride(player, assetType, idOrKey, nil)
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
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")
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
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")

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
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")

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
): Observable.Observable<boolean>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")
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
): Observable.Observable<()>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_observePlayerProductManagerBrio(player):Pipe({
		RxBrioUtils.flattenToValueAndNil :: any,
		RxBrioUtils.switchMapBrio(function(playerProductManager): any
			if playerProductManager then
				local ownershipTracker = playerProductManager:GetOwnershipTrackerOrError(assetType)
				return ownershipTracker:ObserveAssetPurchased(idOrKey)
			else
				return Rx.EMPTY
			end
		end) :: any,
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
			end) :: any,
			Rx.map(function(brio)
				-- I THINK THIS LEAKS
				if brio:IsDead() then
					return nil
				end

				return brio:GetValue()
			end) :: any,
			Rx.where(function(value)
				return value ~= nil
			end) :: any,
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
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")
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
					return self:_promiseGuardedPromptPurchase(player, assetTracker, idOrKey) :: any
				end
			end)
		else
			-- Assume this is a single session purchase
			if assetTracker:HasPurchasedThisSession(idOrKey) then
				return Promise.resolved(true)
			end

			return self:_promiseGuardedPromptPurchase(player, assetTracker, idOrKey)
		end
	end)
end

function GameProductDataService._observePlayerProductManagerBrio(
	self: GameProductDataService,
	player: Player
): Observable.Observable<Brio.Brio<any>>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")

	return PlayerProductManagerInterface:ObserveBrio(player, self._tieRealmService:GetTieRealm())
end

function GameProductDataService._promisePlayerProductManager(
	self: GameProductDataService,
	player: Player
): Promise.Promise<any>
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")

	return PlayerProductManagerInterface:Promise(player, self._tieRealmService:GetTieRealm())
end

function GameProductDataService._getPlayerProductManager(self: GameProductDataService, player: Player): any
	assert((typeof(player) == "Instance" and player:IsA("Player")) or PlayerMock.isMock(player), "Bad player")

	return PlayerProductManagerInterface:Find(player, self._tieRealmService:GetTieRealm())
end

function GameProductDataService.Destroy(self: GameProductDataService)
	self._maid:DoCleaning()
end

return GameProductDataService
