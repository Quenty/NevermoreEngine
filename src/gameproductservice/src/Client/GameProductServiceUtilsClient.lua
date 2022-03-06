--[=[
    @class GameProductServiceUtilsClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Promise = require("Promise")
local GameConfigServiceClient = require("GameConfigServiceClient")
local ServiceBag = require("ServiceBag")
local GameConfigAssetTypes = require("GameConfigAssetTypes")

local GameProductServiceUtilsClient = {}

function GameProductServiceUtilsClient.toAssetId(serviceBag, assetType, assetIdOrKey)
	assert(type(assetIdOrKey) == "number" or type(assetIdOrKey) == "string", "Bad assetIdOrKey")

	local gameConfigServiceClient = serviceBag:GetService(GameConfigServiceClient)

	if type(assetIdOrKey) == "string" then
		local picker = gameConfigServiceClient:GetConfigPicker()
		local asset = picker:FindFirstActiveAssetOfKey(assetType, assetIdOrKey)
		if asset then
			return asset:GetAssetId()
		else
			return nil
		end
	end

	return assetIdOrKey
end

function GameProductServiceUtilsClient.promisePurchasedOrPrompt(serviceBag, passIdOrKey)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	local gameProductServiceClient = serviceBag:GetService(require("GameProductServiceClient"))
	local gamepassId = GameProductServiceUtilsClient.toAssetId(serviceBag, GameConfigAssetTypes.PASS, passIdOrKey)
	if not gamepassId then
		return Promise.rejected(("No asset with key %q"):format(tostring(passIdOrKey)))
	end

	return gameProductServiceClient:PromiseLocalPlayerOwnsPass(gamepassId)
		:Then(function(owned)
			if not owned then
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, gamepassId)
			end

			return owned
		end)
end

function GameProductServiceUtilsClient.promiseGamepassOrProductUnlockOrPrompt(serviceBag, passIdOrKey, productIdOrKey)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	assert(passIdOrKey, "Bad passIdOrKey")
	assert(productIdOrKey, "Bad productIdOrKey")

	local gameProductServiceClient = serviceBag:GetService(require("GameProductServiceClient"))
	local productId = GameProductServiceUtilsClient.toAssetId(serviceBag, GameConfigAssetTypes.PRODUCT, productIdOrKey)
	if not productId then
		return Promise.rejected(("No asset with key %q"):format(tostring(productIdOrKey)))
	end

	local gamepassId = GameProductServiceUtilsClient.toAssetId(serviceBag, GameConfigAssetTypes.PASS, passIdOrKey)
	if not gamepassId then
		return Promise.rejected(("No asset with key %q"):format(tostring(passIdOrKey)))
	end

	if gameProductServiceClient:HasPurchasedProductThisSession(productId) then
		return Promise.resolved(true)
	end

	return gameProductServiceClient:PromiseLocalPlayerOwnsPass(gamepassId)
		:Then(function(owned)
			if owned then
				return owned
			end

			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
			return owned
		end)
end

return GameProductServiceUtilsClient