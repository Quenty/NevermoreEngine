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
local GameProductServiceHelper = require("GameProductServiceHelper")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local Signal = require("Signal")
local RxBinderUtils = require("RxBinderUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")

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
	self._gameConfigService = self._serviceBag:GetService(require("GameConfigService"))
	self._serviceBag:GetService(require("ReceiptProcessingService"))

	-- Internal
	self._binders = self._serviceBag:GetService(require("GameProductBindersServer"))

	-- Configure
	self._helper = GameProductServiceHelper.new(self._binders.PlayerProductManager)
	self._maid:GiveTask(self._helper)

	-- Additional API for ergonomics
	self.GamePassPurchased = Signal.new() -- :Fire(player, gamePassId)
	self._maid:GiveTask(self.GamePassPurchased)

	self.ProductPurchased = Signal.new() -- :Fire(player, productId)
	self._maid:GiveTask(self.ProductPurchased)

	self.AssetPurchased = Signal.new() -- :Fire(player, assetId)
	self._maid:GiveTask(self.AssetPurchased)

	self.BundlePurchased = Signal.new() -- :Fire(player, bundleId)
	self._maid:GiveTask(self.BundlePurchased)
end

--[=[
	Starts the service. Should be done via [ServiceBag]
]=]
function GameProductService:Start()
	self._maid:GiveTask(RxBinderUtils.observeAllBrio(self._binders.PlayerProductManager):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local playerProductManager = brio:GetValue()
		local playerMarketeer = playerProductManager:GetMarketeer()

		local function exposeSignal(signal, assetType)
			maid:GiveTask(playerMarketeer:GetAssetTrackerOrError(assetType).Purchased:Connect(function(...)
				signal:Fire(playerProductManager:GetPlayer(), ...)
			end))
		end

		exposeSignal(self.GamePassPurchased, GameConfigAssetTypes.PASS)
		exposeSignal(self.ProductPurchased, GameConfigAssetTypes.PRODUCT)
		exposeSignal(self.AssetPurchased, GameConfigAssetTypes.ASSET)
		exposeSignal(self.BundlePurchased, GameConfigAssetTypes.BUNDLE)
	end))
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

	return self._helper:ObservePlayerAssetPurchased(assetType, idOrKey)
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

	return self._helper:ObserveAssetPurchased(assetType, idOrKey)
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

	return self._helper:HasPlayerPurchasedThisSession(player, assetType, idOrKey)
end

--[=[
	Returns true if the prompt is open

	@param player Player
	@return Promise<boolean>
]=]
function GameProductService:PromisePlayerIsPromptOpen(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self._serviceBag, "Not initialized")

	return self._helper:PromisePlayerIsPromptOpen(player)
end

--[=[
	Returns a promise that will resolve when all prompts are closed

	@param player Player
	@return Promise
]=]
function GameProductService:PromisePlayerPromptClosed(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self._serviceBag, "Not initialized")

	return self._helper:PromisePlayerPromptClosed(player)
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

	return self._helper:PromisePromptPurchase(player, assetType, idOrKey)
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

	return self._helper:PromisePlayerOwnership(player, assetType, idOrKey)
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

	return self._helper:PromisePlayerOwnershipOrPrompt(player, assetType, idOrKey)
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

	return self._helper:ObservePlayerOwnership(player, assetType, idOrKey)
end

--[=[
	Cleans up the game product service
]=]
function GameProductService:Destroy()
	self._maid:DoCleaning()
end

return GameProductService