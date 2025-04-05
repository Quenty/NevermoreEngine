--[=[
	This service provides an interface to purchase produces, assets, and other
	marketplace items. This listens to events, handles requests between server and
	client, and takes in both assetKeys from GameConfigService, as well as
	assetIds.

	See [GameProductService] for the server equivalent. The API surface should be
	effectively the same between the two.

	@client
	@class GameProductServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local Maid = require("Maid")
local Promise = require("Promise")
local Signal = require("Signal")
local _ServiceBag = require("ServiceBag")
local _Observable = require("Observable")

local GameProductServiceClient = {}
GameProductServiceClient.ServiceName = "GameProductServiceClient"

--[=[
	Initializes the service. Should be done via [ServiceBag]
	@param serviceBag ServiceBag
]=]
function GameProductServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("AvatarEditorInventoryServiceClient"))
	self._serviceBag:GetService(require("CmdrServiceClient"))
	self._serviceBag:GetService(require("CatalogSearchServiceCache"))
	self._serviceBag:GetService(require("GameConfigServiceClient"))

	-- Internal
	self._gameProductDataService = self._serviceBag:GetService(require("GameProductDataService"))
	self._serviceBag:GetService(require("PlayerProductManagerClient"))

	-- Additional API for ergonomics
	self.GamePassPurchased = self._maid:Add(Signal.new()) -- :Fire(gamePassId)
	self.ProductPurchased = self._maid:Add(Signal.new()) -- :Fire(productId)
	self.AssetPurchased = self._maid:Add(Signal.new()) -- :Fire(assetId)
	self.BundlePurchased = self._maid:Add(Signal.new()) -- :Fire(bundleId)
	self.SubscriptionPurchased = self._maid:Add(Signal.new()) -- :Fire(subscriptionId)
	self.MembershipPurchased = self._maid:Add(Signal.new()) -- :Fire(membershipId)
end

--[=[
	Starts the service. Should be done via [ServiceBag]
]=]
function GameProductServiceClient:Start()
	local function forwardSignal(origSignal, signal)
		self._maid:GiveTask(origSignal:Connect(function(player, ...)
			if player == Players.LocalPlayer then
				signal:Fire(...)
			end
		end))
	end

	forwardSignal(self._gameProductDataService.GamePassPurchased, self.GamePassPurchased)
	forwardSignal(self._gameProductDataService.ProductPurchased, self.ProductPurchased)
	forwardSignal(self._gameProductDataService.AssetPurchased, self.AssetPurchased)
	forwardSignal(self._gameProductDataService.BundlePurchased, self.BundlePurchased)
	forwardSignal(self._gameProductDataService.SubscriptionPurchased, self.SubscriptionPurchased)
	forwardSignal(self._gameProductDataService.MembershipPurchased, self.MembershipPurchased)
end

--[=[
	Fires when the specified player purchases an asset

	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<>
]=]
function GameProductServiceClient:ObservePlayerAssetPurchased(assetType, idOrKey)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:ObservePlayerAssetPurchased(assetType, idOrKey)
end

--[=[
	Fires when any player purchases an asset

	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<boolean>
]=]
function GameProductServiceClient:ObserveAssetPurchased(
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): _Observable.Observable<boolean>
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:ObserveAssetPurchased(assetType, idOrKey)
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return boolean
]=]
function GameProductServiceClient:HasPlayerPurchasedThisSession(
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): boolean
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:HasPlayerPurchasedThisSession(player, assetType, idOrKey)
end

--[=[
	Prompts the user to purchase the asset, and returns true if purchased

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductServiceClient:PromisePromptPurchase(
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:PromisePromptPurchase(player, assetType, idOrKey)
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductServiceClient:PromisePlayerOwnership(
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:PromisePlayerOwnership(player, assetType, idOrKey)
end

--[=[
	Observes if the player owns this cloud asset or not

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<boolean>
]=]
function GameProductServiceClient:ObservePlayerOwnership(
	player: Player,
	assetType,
	idOrKey: string | number
): _Observable.Observable<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:ObservePlayerOwnership(player, assetType, idOrKey)
end

--[=[
	Returns true if the prompt is open

	@param player Player
	@return Promise<boolean>
]=]
function GameProductServiceClient:PromisePlayerIsPromptOpen(player: Player): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self ~= GameProductServiceClient, "Use serviceBag")
	assert(self._serviceBag, "Not initialized")

	return self._gameProductDataService:PromisePlayerIsPromptOpen(player)
end

--[=[
	Returns a promise that will resolve when all prompts are closed

	@param player Player
	@return Promise
]=]
function GameProductServiceClient:PromisePlayerPromptClosed(player: Player): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self ~= GameProductServiceClient, "Use serviceBag")
	assert(self._serviceBag, "Not initialized")

	return self._gameProductDataService:PromisePlayerPromptClosed(player)
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
function GameProductServiceClient:PromisePlayerOwnershipOrPrompt(
	player: Player,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	idOrKey: string | number
): Promise.Promise<boolean>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:PromisePlayerOwnershipOrPrompt(player, assetType, idOrKey)
end

--[=[
	Promises to either check a gamepass or a product to see if it's purchased.

	@param gamePassIdOrKey string | number
	@param productIdOrKey string | number
	@return Promise<boolean>
]=]
function GameProductServiceClient:PromiseGamePassOrProductUnlockOrPrompt(
	gamePassIdOrKey: string | number,
	productIdOrKey: string | number
): Promise.Promise<boolean>
	assert(type(gamePassIdOrKey) == "number" or type(gamePassIdOrKey) == "string", "Bad gamePassIdOrKey")
	assert(type(productIdOrKey) == "number" or type(productIdOrKey) == "string", "Bad productIdOrKey")

	if self:HasPlayerPurchasedThisSession(Players.LocalPlayer, GameConfigAssetTypes.PRODUCT, productIdOrKey) then
		return Promise.resolved(true)
	end

	return self:PromisePlayerOwnership(Players.LocalPlayer, GameConfigAssetTypes.PASS, gamePassIdOrKey)
		:Then(function(owns)
			if owns then
				return true
			else
				return self:PromisePromptPurchase(Players.LocalPlayer, GameConfigAssetTypes.PRODUCT, productIdOrKey)
			end
		end)
end

function GameProductServiceClient:Destroy()
	self._maid:DoCleaning()
end

return GameProductServiceClient
