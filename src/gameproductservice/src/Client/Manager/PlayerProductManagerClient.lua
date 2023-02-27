--[=[
	@client
	@class PlayerProductManagerClient
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local BaseObject = require("BaseObject")
local PlayerProductManagerConstants = require("PlayerProductManagerConstants")
local GameConfigServiceClient = require("GameConfigServiceClient")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local PlayerMarketeer = require("PlayerMarketeer")

local PlayerProductManagerClient = setmetatable({}, BaseObject)
PlayerProductManagerClient.ClassName = "PlayerProductManagerClient"
PlayerProductManagerClient.__index = PlayerProductManagerClient

require("PromiseRemoteEventMixin"):Add(PlayerProductManagerClient, PlayerProductManagerConstants.REMOTE_EVENT_NAME)

function PlayerProductManagerClient.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), PlayerProductManagerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigServiceClient = self._serviceBag:GetService(GameConfigServiceClient)

	if self._obj == Players.LocalPlayer then
		self._marketeer = PlayerMarketeer.new(self._obj, self._gameConfigServiceClient:GetConfigPicker())
		self._maid:GiveTask(self._marketeer)

		self:_connectMarketplace()

		-- Configure remote events
		self:_replicateRemoteEventType(GameConfigAssetTypes.ASSET)
		self:_replicateRemoteEventType(GameConfigAssetTypes.BUNDLE)
		self:_replicateRemoteEventType(GameConfigAssetTypes.PASS)
		self:_replicateRemoteEventType(GameConfigAssetTypes.PRODUCT)
	end

	return self
end

--[=[
	@return PlayerMarketeer
]=]
function PlayerProductManagerClient:GetMarketeer()
	return self._marketeer
end

function PlayerProductManagerClient:_replicateRemoteEventType(assetType)
	local tracker = self._marketeer:GetAssetTrackerOrError(assetType)

	self._maid:GiveTask(tracker.PromptFinished:Connect(function(assetId, isPurchased)
		self:PromiseRemoteEvent():Then(function(remoteEvent)
			remoteEvent:FireServer(PlayerProductManagerConstants.NOTIFY_PROMPT_FINISHED, assetType, assetId, isPurchased)
		end)
	end))
end

--[=[
	Gets the current player
	@return Player
]=]
function PlayerProductManagerClient:GetPlayer()
	return self._obj
end

function PlayerProductManagerClient:_connectMarketplace()
	-- Assets
	self._maid:GiveTask(MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
		if player == self._obj then
			local tracker = self._marketeer:GetAssetTrackerOrError(GameConfigAssetTypes.ASSET)
			tracker:HandlePurchaseEvent(assetId, isPurchased)
		end
	end))

	-- Products
	self._maid:GiveTask(MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if self._obj.UserId == userId then
			local tracker = self._marketeer:GetAssetTrackerOrError(GameConfigAssetTypes.PRODUCT)
			tracker:HandlePurchaseEvent(productId, isPurchased)
		end
	end))

	-- Game passes
	self._maid:GiveTask(MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, isPurchased)
		if player == self._obj then
			local tracker = self._marketeer:GetAssetTrackerOrError(GameConfigAssetTypes.PASS)
			tracker:HandlePurchaseEvent(gamePassId, isPurchased)
		end
	end))

	-- Bundles
	self._maid:GiveTask(MarketplaceService.PromptBundlePurchaseFinished:Connect(function(player, bundleId, isPurchased)
		if player == self._obj then
			local tracker = self._marketeer:GetAssetTrackerOrError(GameConfigAssetTypes.BUNDLE)
			tracker:HandlePurchaseEvent(bundleId, isPurchased)
		end
	end))
end

return PlayerProductManagerClient