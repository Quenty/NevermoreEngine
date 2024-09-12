--[=[
	This service provides an interface to purchase produces, assets, and other
	marketplace items. This listens to events, handles requests between server and
	client, and takes in both assetKeys from GameConfigService, as well as
	assetIds.

	See [GameProductServiceClient] for the client equivalent. The API surface should be
	effectively the same between the two.

	@server
	@class GameProductService
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")

local GameProductService = {}
GameProductService.ServiceName = "GameProductService"

--[=[
	Initializes the service. Should be done via [ServiceBag]
	@param serviceBag ServiceBag
]=]
function GameProductService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("GameConfigService"))
	self._serviceBag:GetService(require("ReceiptProcessingService"))
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._gameProductDataService = self._serviceBag:GetService(require("GameProductDataService"))
	self._serviceBag:GetService(require("PlayerProductManager"))
	self._serviceBag:GetService(require("GameProductCmdrService"))


	-- Additional API for ergonomics
	self.GamePassPurchased = assert(self._gameProductDataService.GamePassPurchased, "No GamePassPurchased") -- :Fire(player, gamePassId)
	self.ProductPurchased = assert(self._gameProductDataService.ProductPurchased, "No ProductPurchased") -- :Fire(player, productId)
	self.AssetPurchased = assert(self._gameProductDataService.AssetPurchased, "No AssetPurchased") -- :Fire(player, assetId)
	self.BundlePurchased = assert(self._gameProductDataService.BundlePurchased, "No BundlePurchased") -- :Fire(player, bundleId)
	self.MembershipPurchased = assert(self._gameProductDataService.MembershipPurchased, "No MembershipPurchased") -- :Fire(player, assetId)
	self.SubscriptionPurchased = assert(self._gameProductDataService.SubscriptionPurchased, "No SubscriptionPurchased") -- :Fire(player, bundleId)
end

--[=[
	Fires when the specified player purchases an asset

	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<>
]=]
function GameProductService:ObservePlayerAssetPurchased(assetType, idOrKey)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:ObservePlayerAssetPurchased(assetType, idOrKey)
end

--[=[
	Fires when any player purchases an asset

	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<Player>
]=]
function GameProductService:ObserveAssetPurchased(assetType, idOrKey)
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
function GameProductService:HasPlayerPurchasedThisSession(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:HasPlayerPurchasedThisSession(player, assetType, idOrKey)
end

--[=[
	Returns true if the prompt is open

	@param player Player
	@return Promise<boolean>
]=]
function GameProductService:PromisePlayerIsPromptOpen(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self._serviceBag, "Not initialized")

	return self._gameProductDataService:PromisePlayerIsPromptOpen(player)
end

--[=[
	Returns a promise that will resolve when all prompts are closed

	@param player Player
	@return Promise
]=]
function GameProductService:PromisePlayerPromptClosed(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self._serviceBag, "Not initialized")

	return self._gameProductDataService:PromisePlayerPromptClosed(player)
end

--[=[
	Prompts the user to purchase the asset, and returns true if purchased

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return boolean
]=]
function GameProductService:PromisePlayerPromptPurchase(player, assetType, idOrKey)
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
function GameProductService:PromisePlayerOwnership(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:PromisePlayerOwnership(player, assetType, idOrKey)
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
function GameProductService:PromisePlayerOwnershipOrPrompt(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:PromisePlayerOwnershipOrPrompt(player, assetType, idOrKey)
end

--[=[
	Observes if the player owns this cloud asset or not

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<boolean>
]=]
function GameProductService:ObservePlayerOwnership(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._gameProductDataService:ObservePlayerOwnership(player, assetType, idOrKey)
end

--[=[
	Cleans up the game product service
]=]
function GameProductService:Destroy()
	self._maid:DoCleaning()
end

return GameProductService