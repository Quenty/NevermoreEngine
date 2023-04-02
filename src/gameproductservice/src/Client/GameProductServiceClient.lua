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
local Maid = require("Maid")
local Promise = require("Promise")
local RxBinderUtils = require("RxBinderUtils")
local Signal = require("Signal")
local GameProductServiceHelper = require("GameProductServiceHelper")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")

local GameProductServiceClient = {}
GameProductServiceClient.ServiceName = "GameProductServiceClient"

--[=[
	Initializes the service. Should be done via [ServiceBag]
	@param serviceBag ServiceBag
]=]
function GameProductServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._gameConfigService = self._serviceBag:GetService(require("GameConfigServiceClient"))

	-- Internal
	self._binders = self._serviceBag:GetService(require("GameProductBindersClient"))

	self._helper = GameProductServiceHelper.new(self._binders.PlayerProductManager)
	self._maid:GiveTask(self._helper)

	-- Additional API for ergonomics
	self.GamePassPurchased = Signal.new() -- :Fire(gamePassId)
	self._maid:GiveTask(self.GamePassPurchased)

	self.ProductPurchased = Signal.new() -- :Fire(productId)
	self._maid:GiveTask(self.ProductPurchased)

	self.AssetPurchased = Signal.new() -- :Fire(assetId)
	self._maid:GiveTask(self.AssetPurchased)

	self.BundlePurchased = Signal.new() -- :Fire(bundleId)
	self._maid:GiveTask(self.BundlePurchased)
end

--[=[
	Starts the service. Should be done via [ServiceBag]
]=]
function GameProductServiceClient:Start()
	self._maid:GiveTask(RxBinderUtils.observeBoundClassBrio(self._binders.PlayerProductManager, Players.LocalPlayer):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local playerProductManager = brio:GetValue()
		local playerMrketeer = playerProductManager:GetMarketeer()

		local function exposeSignal(signal, assetType)
			maid:GiveTask(playerMrketeer:GetAssetTrackerOrError(assetType).Purchased:Connect(function(...)
				signal:Fire(...)
			end))
		end

		exposeSignal(self.GamePassPurchased, GameConfigAssetTypes.PASS)
		exposeSignal(self.ProductPurchased, GameConfigAssetTypes.PRODUCT)
		exposeSignal(self.AssetPurchased, GameConfigAssetTypes.ASSET)
		exposeSignal(self.BundlePurchased, GameConfigAssetTypes.BUNDLE)
	end))
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return boolean
]=]
function GameProductServiceClient:HasPlayerPurchasedThisSession(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._helper:HasPlayerPurchasedThisSession(player, assetType, idOrKey)
end

--[=[
	Prompts the user to purchase the asset, and returns true if purchased

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductServiceClient:PromisePromptPurchase(player, assetType, idOrKey)
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
function GameProductServiceClient:PromisePlayerOwnership(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._helper:PromisePlayerOwnership(player, assetType, idOrKey)
end

--[=[
	Observes if the player owns this cloud asset or not

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<boolean>
]=]
function GameProductServiceClient:ObservePlayerOwnership(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._helper:ObservePlayerOwnership(player, assetType, idOrKey)
end

--[=[
	Returns true if the prompt is open
	@return boolean
]=]
function GameProductServiceClient:PromisePlayerIsPromptOpen(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self ~= GameProductServiceClient, "Use serviceBag")
	assert(self._serviceBag, "Not initialized")

	return self._helper:PromisePlayerIsPromptOpen(player)
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
function GameProductServiceClient:PromisePlayerOwnershipOrPrompt(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._helper:PromisePlayerOwnershipOrPrompt(player, assetType, idOrKey)
end

--[=[
	Promises to either check a gamepass or a product to see if it's purchased.

	@param gamePassIdOrKey string | number
	@param productIdOrKey string | number
	@return Promise<boolean>
]=]
function GameProductServiceClient:PromiseGamePassOrProductUnlockOrPrompt(gamePassIdOrKey, productIdOrKey)
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

return GameProductServiceClient