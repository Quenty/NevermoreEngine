--[=[
	@class GameProductServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Maid = require("Maid")
local GameProductServiceBase = require("GameProductServiceBase")
local Signal = require("Signal")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local Promise = require("Promise")

local GameProductServiceClient = GameProductServiceBase.new()

function GameProductServiceClient:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._gameConfigService = self._serviceBag:GetService(require("GameConfigServiceClient"))

	-- Internal
	self._binders = self._serviceBag:GetService(require("GameProductBindersClient"))

	self.GamepassPurchased = Signal.new() -- :Fire(gamepassId)
	self._maid:GiveTask(self.GamepassPurchased)

	self.DevProductPurchased = Signal.new() -- :Fire(productId)
	self._maid:GiveTask(self.DevProductPurchased)

	self._promptClosedEvent = Signal.new()
	self._maid:GiveTask(self._promptClosedEvent)

	self._purchasedGamePassesThisSession = {}
	self._maid:GiveTask(MarketplaceService.PromptGamePassPurchaseFinished
		:Connect(function(player, gamepassId, wasPurchased)
			if player == Players.LocalPlayer then
				self._promptClosedEvent:Fire()
				if wasPurchased then
					self._purchasedGamePassesThisSession[gamepassId] = true
					-- self._fireworksService:Create(3)
					self.GamepassPurchased:Fire(gamepassId)
				end
			end
		end))

	self._purchasedDevProductsThisSession = {}
	self._maid:GiveTask(MarketplaceService.PromptProductPurchaseFinished
		:Connect(function(userId, productId, wasPurchased)
			if userId == Players.LocalPlayer.UserId then
				self._promptClosedEvent:Fire()
				if wasPurchased then
					-- self._fireworksService:Create(3)
					self._purchasedDevProductsThisSession[productId] = true
					self.DevProductPurchased:Fire(productId)
				end
			end
		end))
end

--[=[
	Promises whether the local player owns the pass or not
	@param passIdOrKey string | number
	@return Promise<boolean>
]=]
function GameProductServiceClient:PromiseLocalPlayerOwnsPass(passIdOrKey)
	assert(type(passIdOrKey) == "number" or type(passIdOrKey) == "string", "Bad passIdOrKey")

	local passId = self:ToAssetId(GameConfigAssetTypes.PASS, passIdOrKey)
	if not passId then
		return Promise.rejected(("No asset with key %q"):format(tostring(passIdOrKey)))
	end

	if self._purchasedGamePassesThisSession[passId] == true then
		return Promise.resolved(self._purchasedGamePassesThisSession[passId])
	end

	return self:PromisePlayerOwnsPass(Players.LocalPlayer, passId)
end

--[=[
	Observes whether the local player owns the pass or not
	@param passIdOrKey string | number
	@return Observable<boolean>
]=]
function GameProductServiceBase:ObserveLocalPlayerOwnsPass(passIdOrKey)
	assert(type(passIdOrKey) == "number" or type(passIdOrKey) == "string", "Bad passIdOrKey")

	return self:ObservePlayerOwnsPass(Players.LocalPlayer, passIdOrKey)
end

function GameProductServiceClient:GetPlayerProductManagerBinder()
	return self._binders.PlayerProductManager
end

function GameProductServiceClient:FlagPromptOpen()
	assert(self ~= GameProductServiceClient, "Use serviceBag")
	assert(self._serviceBag, "Not initialized")

	self._promptOpenFlag = true
end

function GameProductServiceClient:GuessIfPromptOpenFromFlags()
	assert(self ~= GameProductServiceClient, "Use serviceBag")
	assert(self._serviceBag, "Not initialized")

	return self._promptOpenFlag
end

function GameProductServiceClient:HasPurchasedProductThisSession(productIdOrKey)
	assert(self ~= GameProductServiceClient, "Use serviceBag")
	assert(self._serviceBag, "Not initialized")
	assert(type(productIdOrKey) == "number" or type(productIdOrKey) == "string", "productIdOrKey")

	local productId = self:ToAssetId(GameConfigAssetTypes.PRODUCT, productIdOrKey)
	if not productId then
		warn(("No asset with key %q"):format(tostring(productIdOrKey)))
		return false
	end

	if self._purchasedDevProductsThisSession[productIdOrKey] then
		return true
	end

	return false
end

function GameProductServiceClient:PromisePurchasedOrPrompt(passIdOrKey)
	local gamepassId = self:ToAssetId(GameConfigAssetTypes.PASS, passIdOrKey)
	if not gamepassId then
		return Promise.rejected(("No asset with key %q"):format(tostring(passIdOrKey)))
	end

	return self:PromiseLocalPlayerOwnsPass(gamepassId)
		:Then(function(owned)
			if not owned then
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, gamepassId)
			end

			return owned
		end)
end

function GameProductServiceClient:PromiseGamepassOrProductUnlockOrPrompt(passIdOrKey, productIdOrKey)
	assert(passIdOrKey, "Bad passIdOrKey")
	assert(productIdOrKey, "Bad productIdOrKey")

	local productId = self:ToAssetId(GameConfigAssetTypes.PRODUCT, productIdOrKey)
	if not productId then
		return Promise.rejected(("No asset with key %q"):format(tostring(productIdOrKey)))
	end

	local gamepassId = self:ToAssetId(GameConfigAssetTypes.PASS, passIdOrKey)
	if not gamepassId then
		return Promise.rejected(("No asset with key %q"):format(tostring(passIdOrKey)))
	end

	if self:HasPurchasedProductThisSession(productId) then
		return Promise.resolved(true)
	end

	return self:PromiseLocalPlayerOwnsPass(gamepassId)
		:Then(function(owned)
			if owned then
				return owned
			end

			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
			return owned
		end)
end

return GameProductServiceClient