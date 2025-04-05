--[=[
	@client
	@class PlayerProductManagerClient
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local AvatarEditorInventoryServiceClient = require("AvatarEditorInventoryServiceClient")
local Binder = require("Binder")
local CatalogSearchServiceCache = require("CatalogSearchServiceCache")
local EnumUtils = require("EnumUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local MarketplaceUtils = require("MarketplaceUtils")
local PlayerProductManagerBase = require("PlayerProductManagerBase")
local PlayerProductManagerInterface = require("PlayerProductManagerInterface")
local Remoting = require("Remoting")
local Promise = require("Promise")

local PlayerProductManagerClient = setmetatable({}, PlayerProductManagerBase)
PlayerProductManagerClient.ClassName = "PlayerProductManagerClient"
PlayerProductManagerClient.__index = PlayerProductManagerClient

function PlayerProductManagerClient.new(obj, serviceBag)
	local self = setmetatable(PlayerProductManagerBase.new(obj, serviceBag), PlayerProductManagerClient)

	self._avatarEditorInventoryServiceClient = self._serviceBag:GetService(AvatarEditorInventoryServiceClient)
	self._catalogSearchServiceCache = self._serviceBag:GetService(CatalogSearchServiceCache)

	if self._obj == Players.LocalPlayer then
		self._remoting = self._maid:Add(Remoting.new(self._obj, "PlayerProductManager", Remoting.Realms.CLIENT))

		self:_setupAssetTracker()
		self:_setupMembershipTracker()
		self:_setupSubscriptionTracker()
		self:_setupProductTracker()
		self:_setupBundleTracker()
		self:_connectGamePassTracker()

		self:_connectBulkPurchaseMarketplace()
	end

	local impl = self._maid:Add(PlayerProductManagerInterface.Client:Implement(self._obj, self))
	self:ExportMarketTrackers(impl:GetImplParent())

	return self
end

--[=[
	Gets the current player
	@return Player
]=]
function PlayerProductManagerClient:GetPlayer()
	return self._obj
end

function PlayerProductManagerClient:_setupAssetTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.ASSET)
	local assetOwnership = assert(tracker:GetOwnershipTracker(), "Missing ownershipTracker on client")

	assetOwnership:SetQueryOwnershipCallback(function(assetId)
		return self:_promiseBulkOwnsAssetQuery(assetId)
	end)

	self._maid:GiveTask(MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
		if player == self._obj then
			tracker:HandlePromptClosedEvent(assetId)
			tracker:HandlePurchaseEvent(assetId, isPurchased)
			self._remoting.AssetPromptPurchaseFinished:FireServer(assetId, isPurchased)
		end
	end))
end

function PlayerProductManagerClient:_setupMembershipTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.MEMBERSHIP)

	self._maid:GiveTask(MarketplaceService.PromptPremiumPurchaseFinished:Connect(function()
		tracker:HandlePromptClosedEvent(Enum.MembershipType.Premium)

		-- Not great behavior but whatever
		tracker:HandlePurchaseEvent(Enum.MembershipType.Premium, self._obj.MembershipType == true)
	end))

	-- I think this only fires on the server...
	self._maid:GiveTask(Players.PlayerMembershipChanged:Connect(function(player)
		if player == self._obj then
			if player.MembershipType == Enum.MembershipType.Premium then
				tracker:HandlePurchaseEvent(player.MembershipType, true)
			end
		end
	end))
end

function PlayerProductManagerClient:_setupSubscriptionTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.SUBSCRIPTION)

	-- Main event
	self._maid:GiveTask(MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(function(player, subscriptionId, didTryPurchasing)
		if player == self._obj then
			self._remoting.PromptSubscriptionPurchaseFinished:FireServer(subscriptionId, didTryPurchasing)
			tracker:HandlePromptClosedEvent(subscriptionId)

			if not didTryPurchasing then
				tracker:HandlePurchaseEvent(subscriptionId, didTryPurchasing)
			end
		end
	end))

	-- In case it comes from the server
	self._maid:GiveTask(self._remoting.PromptSubscriptionPurchaseFinished:Connect(function(subscriptionId, didTryPurchasing)
		tracker:HandlePromptClosedEvent(subscriptionId)

		if not didTryPurchasing then
			tracker:HandlePurchaseEvent(subscriptionId, didTryPurchasing)
		end
	end))

	self._maid:GiveTask(self._remoting.UserSubscriptionStatusChanged:Connect(function(subscriptionId)
		tracker:HandlePurchaseEvent(subscriptionId, true)
	end))
end

function PlayerProductManagerClient:_connectBulkPurchaseMarketplace()
	self._maid:GiveTask(MarketplaceService.PromptBulkPurchaseFinished:Connect(function(player, status, results)
		if player ~= self._obj then
			return
		end

		-- Update ownership information
		if status == Enum.MarketplaceBulkPurchasePromptStatus.Completed then
			for _, item in results.Items do
				local tracker
				if item.type == Enum.MarketplaceProductType.AvatarAsset then
					tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.ASSET)
				elseif item.type == Enum.MarketplaceProductType.AvatarBundle then
					tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.BUNDLE)
				else
					warn(string.format("[PlayerProductManagerClient] - Unknown Enum.MarketplaceProductType %q", tostring(item.type)))
					continue
				end

				if item.status == Enum.MarketplaceItemPurchaseStatus.Success then
					tracker:HandlePurchaseEvent(tonumber(item.id) or item.id, true)
				else
					tracker:HandlePurchaseEvent(tonumber(item.id) or item.id, false)
				end
			end
		end
	end))
end

function PlayerProductManagerClient:_setupProductTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.PRODUCT)

	self._maid:GiveTask(MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if self._obj.UserId == userId then
			tracker:HandlePromptClosedEvent(productId)

			-- We only read from the server purchase event
			if not isPurchased then
				tracker:HandlePurchaseEvent(productId, isPurchased)
			end

			self._remoting.PromptProductPurchaseFinished:FireServer(productId, isPurchased)
		end
	end))

	self._maid:GiveTask(self._remoting.DeveloperProductPurchased:Connect(function(productId)
		local assetTracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.PRODUCT)
		assetTracker:HandlePurchaseEvent(productId, true)
	end))
end

function PlayerProductManagerClient:_connectGamePassTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.PASS)

	self._maid:GiveTask(MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, isPurchased)
		assert(type(isPurchased) == "boolean", "Bad isPurchased")

		if player == self._obj then
			tracker:HandlePromptClosedEvent(gamePassId)
			tracker:HandlePurchaseEvent(gamePassId, isPurchased)

			self._remoting.PromptGamePassPurchaseFinished:FireServer(gamePassId, isPurchased)
		end
	end))
end

function PlayerProductManagerClient:_setupBundleTracker()
	local tracker = self:GetAssetTrackerOrError(GameConfigAssetTypes.BUNDLE)

	local bundleOwnership = assert(tracker:GetOwnershipTracker(), "Missing ownershipTracker on client")

	bundleOwnership:SetQueryOwnershipCallback(function(assetId)
		return self:_promiseBulkOwnsBundleQuery(assetId, Enum.AvatarItemType.Bundle)
	end)

	self._maid:GiveTask(MarketplaceService.PromptBundlePurchaseFinished:Connect(function(player, bundleId, isPurchased)
		if player == self._obj then
			tracker:HandlePromptClosedEvent(bundleId)
			tracker:HandlePurchaseEvent(bundleId, isPurchased)

			self._remoting.PromptBundlePurchaseFinished:FireServer(bundleId, isPurchased)
		end
	end))
end

function PlayerProductManagerClient:_promiseBulkOwnsAssetQuery(assetId)
	if self._avatarEditorInventoryServiceClient:IsInventoryAccessAllowed() then
		-- When scrolling through a ton of entries in the avatar editor we want to query
		-- this is typically faster. We really hope we aren't the Roblox account.
		return self._catalogSearchServiceCache:PromiseItemDetails(assetId, Enum.AvatarItemType.Asset)
			:Then(function(itemDetails)
				-- https://devforum.roblox.com/t/avatareditorservicegetitemdetails-returns-ownership-where-as-avatareditorservicegetbatchitemdetails-does-not/3257431

				local assetType = EnumUtils.toEnum(Enum.AvatarAssetType, itemDetails.AssetType)
				if not assetType then
					-- TODO: Fallback to standard query?
					return Promise.rejected("Failed to get assetType")
				end

				return self._avatarEditorInventoryServiceClient:PromiseInventoryForAvatarAssetType(assetType)
					:Then(function(inventory)
						return inventory:IsAssetIdInInventory(assetId)
					end)
			end)
	end

	return MarketplaceUtils.promisePlayerOwnsAsset(self._player, assetId)
end

function PlayerProductManagerClient:_promiseBulkOwnsBundleQuery(bundleId)
	return MarketplaceUtils.promisePlayerOwnsBundle(self._player, bundleId)
end

return Binder.new("PlayerProductManager", PlayerProductManagerClient)