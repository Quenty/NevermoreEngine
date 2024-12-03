--[=[
	Handles product prompting state on the server

	@server
	@class PlayerProductManager
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local EnumUtils = require("EnumUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local PlayerBinder = require("PlayerBinder")
local PlayerProductManagerBase = require("PlayerProductManagerBase")
local PlayerProductManagerInterface = require("PlayerProductManagerInterface")
local ReceiptProcessingService = require("ReceiptProcessingService")
local Remoting = require("Remoting")

local PlayerProductManager = setmetatable({}, PlayerProductManagerBase)
PlayerProductManager.ClassName = "PlayerProductManager"
PlayerProductManager.__index = PlayerProductManager

--[=[
	Managers players products and purchase state. Should be retrieved via binder.

	@param player Player
	@param serviceBag ServiceBag
	@return PlayerProductManager
]=]
function PlayerProductManager.new(player, serviceBag)
	local self = setmetatable(PlayerProductManagerBase.new(player, serviceBag), PlayerProductManager)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._receiptProcessingService = self._serviceBag:GetService(ReceiptProcessingService)

	self:_setupRemoting()

	-- Setup each ownership tracker
	self:_setupAssetTracker()
	self:_setupMembershipTracker()
	self:_setupSubscriptionTracker()
	self:_setupProductTracker()
	self:_setupPassTracker()
	self:_setupBundleTracker()

	-- Initialize attributes

	-- Implement
	local impl = self._maid:Add(PlayerProductManagerInterface.Server:Implement(self._obj, self))
	self:ExportMarketTrackers(impl:GetImplParent())

	return self
end

function PlayerProductManager:_setupRemoting()
	self._remoting = self._maid:Add(Remoting.Server.new(self._obj, "PlayerProductManager", Remoting.Realms.SERVER))
end

function PlayerProductManager:_setupAssetTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.ASSET)

	self._maid:GiveTask(self._remoting.AssetPromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
		assert(self._obj == player, "Bad player")
		assert(type(assetId) == "number", "Bad assetId")
		assert(type(isPurchased) == "boolean", "Bad isPurchased")

		-- TODO: Validate on server
		tracker:HandlePromptClosedEvent(assetId, isPurchased)
		tracker:HandlePurchaseEvent(assetId, isPurchased)
	end))
end


function PlayerProductManager:_setupProductTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.PRODUCT)

	-- Source of truth for purchase is here
	self._remoting.DeveloperProductPurchased:DeclareEvent()

	self._maid:GiveTask(self._remoting.PromptProductPurchaseFinished:Connect(function(player, productId, isPurchased)
		assert(self._obj == player, "Bad player")

		tracker:HandlePromptClosedEvent(productId)

		-- We only read from the server purchase event
		if not isPurchased then
			tracker:HandlePurchaseEvent(productId, isPurchased)
		end
	end))

	self._maid:GiveTask(self._receiptProcessingService:ObserveReceiptProcessedForPlayer(self._obj):Subscribe(function(receiptInfo, productPurchaseDecision)
		assert(type(receiptInfo) == "table", "Bad receiptInfo")
		assert(EnumUtils.isOfType(Enum.ProductPurchaseDecision, productPurchaseDecision), "Bad decision")

		local productId = receiptInfo.ProductId
		tracker:HandlePurchaseEvent(productId, true)

		self._remoting.DeveloperProductPurchased:FireClient(self._obj, productId)
	end))
end

function PlayerProductManager:_setupPassTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.PASS)

	self._maid:GiveTask(self._remoting.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, isPurchased)
		assert(player == self._obj, "Bad player")
		assert(type(gamePassId) == "number", "Bad gamePassId")
		assert(type(isPurchased) == "boolean", "Bad isPurchased")

		-- TODO: Validate in purchased scenario
		tracker:HandlePromptClosedEvent(gamePassId)
		tracker:HandlePurchaseEvent(gamePassId, isPurchased)
	end))
end

function PlayerProductManager:_setupMembershipTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.MEMBERSHIP)

	self._maid:GiveTask(Players.PlayerMembershipChanged:Connect(function(player)
		if player == self._obj then
			if player.MembershipType == Enum.MembershipType.Premium then
				tracker:HandlePurchaseEvent(player.MembershipType, true)
			end
		end
	end))
end

function PlayerProductManager:_setupSubscriptionTracker()
	self._remoting.UserSubscriptionStatusChanged:DeclareEvent()

	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.SUBSCRIPTION)

	self._maid:GiveTask(self._remoting.PromptSubscriptionPurchaseFinished:Connect(function(player, subscriptionId)
		assert(player == self._obj, "Bad player")

		tracker:HandlePromptClosedEvent(subscriptionId)
	end))

	-- In case this does anything
	self._maid:GiveTask(MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(function(player, subscriptionId, didTryPurchasing)
		if player == self._obj then
			tracker:HandlePromptClosedEvent(subscriptionId)
			self._remoting.PromptSubscriptionPurchaseFinished:FireClient(player, subscriptionId, didTryPurchasing)

			if not didTryPurchasing then
				tracker:HandlePurchaseEvent(subscriptionId, didTryPurchasing)
			end
		end
	end))

	self._maid:GiveTask(Players.UserSubscriptionStatusChanged:Connect(function(player, subscriptionId)
		if player == self._obj then
			tracker:HandlePurchaseEvent(subscriptionId)
			self._remoting.UserSubscriptionStatusChanged:FireClient(player, subscriptionId)
		end
	end))
end

function PlayerProductManager:_setupBundleTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.BUNDLE)

	self._maid:GiveTask(MarketplaceService.PromptBundlePurchaseFinished:Connect(function(player, bundleId, isPurchased)
		if player == self._obj then
			tracker:HandlePromptClosedEvent(bundleId)
			tracker:HandlePurchaseEvent(bundleId, isPurchased)
		end
	end))

	self._maid:GiveTask(self._remoting.PromptBundlePurchaseFinished:Connect(function(player, bundleId, isPurchased)
		assert(player == self._obj, "Bad player")
		assert(type(bundleId) == "number", "Bad bundleId")
		assert(type(isPurchased) == "boolean", "Bad isPurchased")

		tracker:HandlePromptClosedEvent(bundleId)
		tracker:HandlePurchaseEvent(bundleId, isPurchased)
	end))
end


return PlayerBinder.new("PlayerProductManager", PlayerProductManager)