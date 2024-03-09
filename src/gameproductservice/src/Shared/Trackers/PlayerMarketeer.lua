--[=[
	See [PlayerProductManager] and [PlayerProductManagerClient]

	@class PlayerMarketeer
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")

local BaseObject = require("BaseObject")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local MarketplaceUtils = require("MarketplaceUtils")
local PlayerAssetOwnershipTracker = require("PlayerAssetOwnershipTracker")
local PlayerAssetMarketTracker = require("PlayerAssetMarketTracker")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local Promise = require("Promise")
local Rx = require("Rx")

local PlayerMarketeer = setmetatable({}, BaseObject)
PlayerMarketeer.ClassName = "PlayerMarketeer"
PlayerMarketeer.__index = PlayerMarketeer

--[=[
	Constructs a new PlayerMarketeer in charge of handling market connections

	@param player Player
	@param configPicker GameConfigPicker
	@return PlayerMarketeer
]=]
function PlayerMarketeer.new(player, configPicker)
	local self = setmetatable(BaseObject.new(), PlayerMarketeer)

	self._player = assert(player, "No player")
	self._configPicker = assert(configPicker, "No configPicker")

	self._assetMarketTrackers = {}
	self._ownershipTrackers = {}

	local asset = self:_addAssetTracker(GameConfigAssetTypes.ASSET)
	local bundle = self:_addAssetTracker(GameConfigAssetTypes.BUNDLE)
	local pass = self:_addAssetTracker(GameConfigAssetTypes.PASS)
	local product = self:_addAssetTracker(GameConfigAssetTypes.PRODUCT)

	-- Some assets can be owned and thus, are reflected here
	local passOwnership = self:_addOwnershipTracker(GameConfigAssetTypes.PASS)
	local assetOwnership = self:_addOwnershipTracker(GameConfigAssetTypes.ASSET)
	local bundleOwnership = self:_addOwnershipTracker(GameConfigAssetTypes.BUNDLE)

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

	-- Configure gamepass to be a bit special
	passOwnership:SetQueryOwnershipCallback(function(gamePassId)
		return MarketplaceUtils.promiseUserOwnsGamePass(self._player.UserId, gamePassId)
	end)

	-- Configure assets too
	assetOwnership:SetQueryOwnershipCallback(function(assetId)
		return MarketplaceUtils.promisePlayerOwnsAsset(self._player, assetId)
	end)

	bundleOwnership:SetQueryOwnershipCallback(function(assetId)
		return MarketplaceUtils.promisePlayerOwnsBundle(self._player, assetId)
	end)

	return self
end

--[=[
	Returns true if the asset type can be owned
	@param assetType GameConfigAssetType
	@return PlayerAssetMarketTracker
]=]
function PlayerMarketeer:IsOwnable(assetType)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	return self._ownershipTrackers[assetType] ~= nil
end

--[=[
	Returns true if any prompt is open

	@return boolean
]=]
function PlayerMarketeer:IsPromptOpen()
	for _, assetTracker in pairs(self._assetMarketTrackers) do
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
function PlayerMarketeer:PromisePlayerPromptClosed()
	if not self:IsPromptOpen() then
		return Promise.resolved()
	end

	if self._observeNextNoPromptOpen then
		return Rx.toPromise(self._observeNextNoPromptOpen)
	end

	local observeOpenCounts = {}

	for assetType, assetTracker in pairs(self._assetMarketTrackers) do
		observeOpenCounts[assetType] = assetTracker:ObservePromptOpenCount()
	end

	self._observeNextNoPromptOpen = Rx.combineLatest(observeOpenCounts):Pipe({
		Rx.map(function(state)
			for _, item in pairs(state) do
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
function PlayerMarketeer:GetAssetTrackerOrError(assetType)
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
function PlayerMarketeer:GetOwnershipTrackerOrError(assetType)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	local assetTracker = self._ownershipTrackers[assetType]
	if not assetTracker then
		error(string.format("No ownership tracker for assetType %q", assetType))
	end
	return assetTracker
end

function PlayerMarketeer:_addOwnershipTracker(assetType)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(not self._ownershipTrackers[assetType], "Already have ownership tracker")

	local marketAssetTracker = self:GetAssetTrackerOrError(assetType)

	local ownershipTracker = PlayerAssetOwnershipTracker.new(self._player, self._configPicker, assetType, marketAssetTracker)
	self._maid:GiveTask(ownershipTracker)

	marketAssetTracker:SetOwnershipTracker(ownershipTracker)

	self._ownershipTrackers[assetType] = ownershipTracker

	return ownershipTracker
end

function PlayerMarketeer:_addAssetTracker(assetType)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(not self._assetMarketTrackers[assetType], "Already have tracker")

	local assetMarketTracker = PlayerAssetMarketTracker.new(assetType, function(idOrKey)
		assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

		return self._configPicker:ToAssetId(assetType, idOrKey)
	end, function(idOrKey)
		assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

		return self._configPicker:ObserveToAssetIdBrio(assetType, idOrKey)
	end)
	self._maid:GiveTask(assetMarketTracker)

	self._assetMarketTrackers[assetType] = assetMarketTracker

	return assetMarketTracker
end

return PlayerMarketeer