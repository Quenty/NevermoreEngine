--[=[
	Provides utility methods for MarketplaceService
	@class MarketplaceUtils
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")

local Promise = require("Promise")

local MarketplaceUtils = {}

--[=[
	Product info about the creator. See [MarketplaceService.GetProductInfo].
	@interface CreatorProductInfo
	.CreatorType string -- Either User or Group
	.CreatorTargetId number -- The ID of the creator user or group
	.Name string -- The name/username of the creator
	.Id number -- (Use CreatorTargetId instead)
	@within MarketplaceUtils
]=]

--[=[
	Product info result for assets.
	@interface AssetProductInfo
	.Creator CreatorProductInfo -- A table of information describing the creator of the asset
	.AssetId number -- If InfoType was Asset, this is the ID of the given asset.
	.AssetTypeId number -- The type of asset (e.g. place, model, shirt)*
	.IsForSale boolean -- Describes whether the asset is purchasable
	.IsLimited boolean -- Describes whether the asset is a "limited item" that is no longer (if ever) sold
	.IsLimitedUnique boolean -- Describes whether the asset is a "limited unique" ("Limited U") item
	.IsNew boolean -- Describes whether the asset is marked as "new" in the catalog
	.Remaining number -- The remaining number of items a limited unique item may be sold
	.Sales number -- The number of items the asset has been sold
	.Name string -- The name shown on the asset's page
	.Description string -- The description as shown on the asset's page; can be nil if blank
	.PriceInRobux number -- The cost of purchasing the asset using Robux
	.Created string -- Timestamp of when the asset was created, e.g. 2018-08-01T17:55:11.98Z
	.Updated string -- Timestamp of when the asset was last updated by its creator, e.g. 2018-08-01T17:55:11.98Z
	.ContentRatingTypeId number -- Indicates whether the item is marked as 13+ in catalog
	.MinimumMembershipLevel number -- The minimum subscription level necessary to purchase the item
	.IsPublicDomain boolean -- Describes whether the asset can be taken for free
	@within MarketplaceUtils
]=]

--[=[
	Product info result for gamepasses.
	@interface GamePassOrDeveloperProductInfo
	.Creator CreatorProductInfo -- A table of information describing the creator of the asset
	.ProductId number -- If the InfoType was Product, this is the product ID
	.IconImageAssetId number -- This is the asset ID of the product/pass icon, or 0 if there isn't one
	.Name string -- The name shown on the asset's page
	.Description string -- The description as shown on the asset's page; can be nil if blank
	.PriceInRobux number -- The cost of purchasing the asset using Robux
	.Created string -- Timestamp of when the asset was created, e.g. 2018-08-01T17:55:11.98Z
	.Updated string -- Timestamp of when the asset was last updated by its creator, e.g. 2018-08-01T17:55:11.98Z
	.ContentRatingTypeId number -- Indicates whether the item is marked as 13+ in catalog
	.MinimumMembershipLevel number -- The minimum subscription level necessary to purchase the item
	.IsPublicDomain boolean -- Describes whether the asset can be taken for free
	@within MarketplaceUtils
]=]

--[=[
	Wraps [MarketplaceService.GetProductInfo] and retrieves information about
	@param assetId number
	@param infoType InfoType | nil
	@return Promise<AssetProductInfo | GamePassOrDeveloperProductInfo>
]=]
function MarketplaceUtils.promiseProductInfo(assetId, infoType)
	assert(type(assetId) == "number", "Bad assetId")
	assert(typeof(infoType) == "EnumItem" or infoType == nil, "Bad infoType")

	return Promise.spawn(function(resolve, reject)
		-- We hope this caches
		local productInfo
		local ok, err = pcall(function()
			productInfo = MarketplaceService:GetProductInfo(assetId, infoType)
		end)
		if not ok then
			return reject(err)
		end
		if type(productInfo) ~= "table" then
			return reject("Bad productInfo type")
		end
		return resolve(productInfo)
	end)
end

--[=[
	Converts an enum value (retrieved from MarketplaceService) into a proper enum if possible

	@param assetTypeId number
	@return AssetType | nl
]=]
function MarketplaceUtils.convertAssetTypeIdToAssetType(assetTypeId)
	assert(type(assetTypeId) == "number", "Bad assetTypeId")

	for _, enumItem in pairs(Enum.AssetType:GetEnumItems()) do
		if enumItem.Value == assetTypeId then
			return enumItem
		end
	end

	return nil
end

--[=[
	Converts an enum value (retrieved from MarketplaceService) into a proper enum if possible

	@param assetTypeId number
	@return AvatarAssetType | nil
]=]
function MarketplaceUtils.convertAssetTypeIdToAvatarAssetType(assetTypeId)
	assert(type(assetTypeId) == "number", "Bad assetTypeId")

	for _, enumItem in pairs(Enum.AvatarAssetType:GetEnumItems()) do
		if enumItem.Value == assetTypeId then
			return enumItem
		end
	end

	return nil
end

--[=[
	Retrieves whether a player owns a gamepass.
	@param userId number
	@param gamePassId number
	@return Promise<boolean>
]=]
function MarketplaceUtils.promiseUserOwnsGamePass(userId, gamePassId)
	assert(typeof(userId) == "number", "Bad userId")
	assert(type(gamePassId) == "number", "Bad gamePassId")

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = MarketplaceService:UserOwnsGamePassAsync(userId, gamePassId)
		end)
		if not ok then
			return reject(err)
		end
		if type(result) ~= "boolean" then
			return reject("Bad result type")
		end
		return resolve(result)
	end)
end

--[=[
	Retrieves whether a player owns an asset, such as a hat or some other item.
	@param player Player
	@param assetId number
	@return Promise<boolean>
]=]
function MarketplaceUtils.promisePlayerOwnsAsset(player, assetId)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(assetId) == "number", "Bad assetId")

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = MarketplaceService:PlayerOwnsAsset(player, assetId)
		end)
		if not ok then
			return reject(err)
		end
		if type(result) ~= "boolean" then
			return reject("Bad result type")
		end
		return resolve(result)
	end)
end

--[=[
	Retrieves whether a player owns a bundle
	@param player Player
	@param bundleId number
	@return Promise<boolean>
]=]
function MarketplaceUtils.promisePlayerOwnsBundle(player, bundleId)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(bundleId) == "number", "Bad bundleId")

	return Promise.spawn(function(resolve, reject)
		local result
		local ok, err = pcall(function()
			result = MarketplaceService:PlayerOwnsBundle(player, bundleId)
		end)
		if not ok then
			return reject(err)
		end
		if type(result) ~= "boolean" then
			return reject("Bad result type")
		end
		return resolve(result)
	end)
end

return MarketplaceUtils