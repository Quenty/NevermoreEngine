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
local RxPlayerUtils = require("RxPlayerUtils")
local RxBrioUtils = require("RxBrioUtils")

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

	self._helper = self._maid:Add(GameProductServiceHelper.new(self._binders.PlayerProductManager))

	-- Additional API for ergonomics
	self.GamePassPurchased = self._maid:Add(Signal.new()) -- :Fire(gamePassId)

	self.ProductPurchased = self._maid:Add(Signal.new()) -- :Fire(productId)

	self.AssetPurchased = self._maid:Add(Signal.new()) -- :Fire(assetId)

	self.BundlePurchased = self._maid:Add(Signal.new()) -- :Fire(bundleId)
end

--[=[
	Starts the service. Should be done via [ServiceBag]
]=]
function GameProductServiceClient:Start()
	self._maid:GiveTask(RxPlayerUtils.observeLocalPlayerBrio():Pipe({
		RxBrioUtils.switchMapBrio(function(localPlayer)
			return RxBinderUtils.observeBoundClassBrio(self._binders.PlayerProductManager, localPlayer)
		end)
	}):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local playerProductManager = brio:GetValue()
		local playerMarketeer = playerProductManager:GetMarketeer()

		local function exposeSignal(signal, assetType)
			maid:GiveTask(playerMarketeer:GetAssetTrackerOrError(assetType).Purchased:Connect(function(...)
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
	Fires when the specified player purchases an asset

	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<>
]=]
function GameProductServiceClient:ObservePlayerAssetPurchased(assetType, idOrKey)
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
function GameProductServiceClient:ObserveAssetPurchased(assetType, idOrKey)
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

	@param player Player
	@return Promise<boolean>
]=]
function GameProductServiceClient:PromisePlayerIsPromptOpen(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self ~= GameProductServiceClient, "Use serviceBag")
	assert(self._serviceBag, "Not initialized")

	return self._helper:PromisePlayerIsPromptOpen(player)
end

--[=[
	Returns a promise that will resolve when all prompts are closed

	@param player Player
	@return Promise
]=]
function GameProductServiceClient:PromisePlayerPromptClosed(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(self ~= GameProductServiceClient, "Use serviceBag")
	assert(self._serviceBag, "Not initialized")

	return self._helper:PromisePlayerPromptClosed(player)
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

function GameProductServiceClient:Destroy()
	self._maid:DoCleaning()
end

return GameProductServiceClient