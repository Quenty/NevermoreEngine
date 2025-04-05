--[=[
	See [PlayerProductManager] and [PlayerProductManagerClient]

	@class PlayerProductManagerBase
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")

local BaseObject = require("BaseObject")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local GameConfigDataService = require("GameConfigDataService")
local MarketplaceUtils = require("MarketplaceUtils")
local PlayerAssetMarketTracker = require("PlayerAssetMarketTracker")
local PlayerAssetMarketTrackerInterface = require("PlayerAssetMarketTrackerInterface")
local PlayerAssetOwnershipTracker = require("PlayerAssetOwnershipTracker")
local Promise = require("Promise")
local Rx = require("Rx")
local String = require("String")
local TieRealmService = require("TieRealmService")

local PlayerProductManagerBase = setmetatable({}, BaseObject)
PlayerProductManagerBase.ClassName = "PlayerProductManagerBase"
PlayerProductManagerBase.__index = PlayerProductManagerBase

--[=[
	Constructs a new PlayerProductManagerBase, which provides helper methods for
	the PlayerProductManager.

	@param player Player
	@param serviceBag ServiceBag
	@return PlayerProductManagerBase
]=]
function PlayerProductManagerBase.new(player, serviceBag)
	local self = setmetatable(BaseObject.new(player), PlayerProductManagerBase)

	self._player = assert(player, "No player")

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._tieRealmService = self._serviceBag:GetService(TieRealmService)
	self._gameConfigDataService = self._serviceBag:GetService(GameConfigDataService)

	self._configPicker = self._gameConfigDataService:GetConfigPicker()

	self._assetMarketTrackers = {}
	self._ownershipTrackers = {}

	local asset = self:_addAssetTracker(GameConfigAssetTypes.ASSET)
	local bundle = self:_addAssetTracker(GameConfigAssetTypes.BUNDLE)
	local pass = self:_addAssetTracker(GameConfigAssetTypes.PASS)
	local product = self:_addAssetTracker(GameConfigAssetTypes.PRODUCT)
	local subscription = self:_addAssetTracker(GameConfigAssetTypes.SUBSCRIPTION)
	local membership = self:_addAssetTracker(GameConfigAssetTypes.MEMBERSHIP)

	-- Some assets can be owned and thus, are reflected here
	local passOwnership = self:_addOwnershipTracker(GameConfigAssetTypes.PASS)
	local assetOwnership = self:_addOwnershipTracker(GameConfigAssetTypes.ASSET)
	local bundleOwnership = self:_addOwnershipTracker(GameConfigAssetTypes.BUNDLE)
	local subscriptionOwnership = self:_addOwnershipTracker(GameConfigAssetTypes.SUBSCRIPTION)
	local membershipOwnership = self:_addOwnershipTracker(GameConfigAssetTypes.MEMBERSHIP)

	-- Prompt
	self._maid:GiveTask(asset.ShowPromptRequested:Connect(function(assetId)
		MarketplaceService:PromptPurchase(self._player, assetId)
	end))
	self._maid:GiveTask(bundle.ShowPromptRequested:Connect(function(bundleId)
		MarketplaceService:PromptBundlePurchase(self._player, bundleId)
	end))
	self._maid:GiveTask(pass.ShowPromptRequested:Connect(function(gamePassId)
		MarketplaceService:PromptGamePassPurchase(self._player, gamePassId)
	end))
	self._maid:GiveTask(product.ShowPromptRequested:Connect(function(productId)
		MarketplaceService:PromptProductPurchase(self._player, productId)
	end))
	self._maid:GiveTask(subscription.ShowPromptRequested:Connect(function(subscriptionId)
		MarketplaceService:PromptSubscriptionPurchase(self._player, subscriptionId)
	end))

	self._maid:GiveTask(membership.ShowPromptRequested:Connect(function(membershipType)
		if membershipType == Enum.MembershipType.Premium then
			MarketplaceService:PromptPremiumPurchase(self._player)
		else
			warn(string.format("[PlayerProductManagerBase] - Unsure how to prompt for membershipType %q", tostring(membershipType)))
		end
	end))

	-- Configure gamepass to be a bit special
	passOwnership:SetQueryOwnershipCallback(function(gamePassId)
		return MarketplaceUtils.promiseUserOwnsGamePass(self._player.UserId, gamePassId)
	end)

	-- Configure assets too
	assetOwnership:SetQueryOwnershipCallback(function(assetId)
		-- NOTE: client overrides these to bulk operations
		return MarketplaceUtils.promisePlayerOwnsAsset(self._player, assetId)
	end)

	bundleOwnership:SetQueryOwnershipCallback(function(bundleId)
		-- NOTE: client overrides these to bulk operations
		return MarketplaceUtils.promisePlayerOwnsBundle(self._player, bundleId)
	end)

	subscriptionOwnership:SetQueryOwnershipCallback(function(subscriptionId)
		return MarketplaceUtils.promiseUserSubscriptionStatus(self._player, subscriptionId)
			:Then(function(status)
				return status.IsSubscribed == true
			end)
	end)

	membershipOwnership:SetQueryOwnershipCallback(function(membershipType)
		return Promise.resolved(self._player.MembershipType == membershipType)
	end)

	return self
end

function PlayerProductManagerBase:ExportMarketTrackers(parent)
	for assetType, assetMarketTracker in self._assetMarketTrackers do
		local folder = self._maid:Add(Instance.new("Folder"))
		folder.Name = String.toCamelCase(GameConfigAssetTypeUtils.getPlural(assetType))
		folder.Archivable = false

		self._maid:Add(
			PlayerAssetMarketTrackerInterface:Implement(folder, assetMarketTracker, self._tieRealmService:GetTieRealm())
		)

		folder.Parent = parent
	end
end

--[=[
	Gets the current player
	@return Player
]=]
function PlayerProductManagerBase:GetPlayer(): Player
	return self._obj
end

--[=[
	Returns true if the asset type can be owned
	@param assetType GameConfigAssetType
	@return PlayerAssetMarketTracker
]=]
function PlayerProductManagerBase:IsOwnable(assetType): boolean
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	return self._ownershipTrackers[assetType] ~= nil
end

--[=[
	Returns true if any prompt is open

	@return boolean
]=]
function PlayerProductManagerBase:IsPromptOpen(): boolean
	for _, assetTracker in self._assetMarketTrackers do
		if assetTracker:IsPromptOpen() then
			return true
		end
	end

	return false
end

--[=[
	Promises that no prompt is open

	@return Promise
]=]
function PlayerProductManagerBase:PromisePlayerPromptClosed()
	if not self:IsPromptOpen() then
		return Promise.resolved()
	end

	if self._observeNextNoPromptOpen then
		return Rx.toPromise(self._observeNextNoPromptOpen)
	end

	local observeOpenCounts = {}

	for assetType, assetTracker in self._assetMarketTrackers do
		observeOpenCounts[assetType] = assetTracker:ObservePromptOpenCount()
	end

	self._observeNextNoPromptOpen = Rx.combineLatest(observeOpenCounts):Pipe({
		Rx.map(function(state)
			for _, item in state do
				if item > 0 then
					return false
				end
			end

			return true
		end);
		Rx.where(function(value)
			return value
		end);
		Rx.distinct();
		Rx.share();
	})

	return Rx.toPromise(self._observeNextNoPromptOpen)
end

--[=[
	Gets the current asset tracker

	@param assetType GameConfigAssetType
	@return PlayerAssetMarketTracker
]=]
function PlayerProductManagerBase:GetAssetTrackerOrError(assetType)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	local assetTracker = self._assetMarketTrackers[assetType]
	if not assetTracker then
		error(string.format("No assetTracker for assetType %q", assetType))
	end
	return assetTracker
end

--[=[
	Gets the current asset tracker

	@param assetType GameConfigAssetType
	@return PlayerAssetMarketTracker
]=]
function PlayerProductManagerBase:GetOwnershipTrackerOrError(assetType)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	local assetTracker = self._ownershipTrackers[assetType]
	if not assetTracker then
		error(string.format("No ownership tracker for assetType %q", assetType))
	end
	return assetTracker
end

function PlayerProductManagerBase:_addOwnershipTracker(assetType)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(not self._ownershipTrackers[assetType], "Already have ownership tracker")

	local marketAssetTracker = self:GetAssetTrackerOrError(assetType)

	local ownershipTracker = self._maid:Add(PlayerAssetOwnershipTracker.new(self._player, self._configPicker, assetType, marketAssetTracker))
	marketAssetTracker:SetOwnershipTracker(ownershipTracker)

	self._ownershipTrackers[assetType] = ownershipTracker

	return ownershipTracker
end

function PlayerProductManagerBase:_addAssetTracker(assetType)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(not self._assetMarketTrackers[assetType], "Already have tracker")

	local assetMarketTracker = self._maid:Add(PlayerAssetMarketTracker.new(assetType, function(idOrKey)
		assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

		return self._configPicker:ToAssetId(assetType, idOrKey)
	end, function(idOrKey)
		assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

		return self._configPicker:ObserveToAssetIdBrio(assetType, idOrKey)
	end))

	self._assetMarketTrackers[assetType] = assetMarketTracker

	return assetMarketTracker
end

return PlayerProductManagerBase