--!strict
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
export type CreatorProductInfo = {
	CreatorType: string,
	CreatorTargetId: number,
	Name: string,
	Id: number,
}

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
export type AssetProductInfo = {
	Creator: CreatorProductInfo,
	AssetId: number,
	AssetTypeId: number,
	IsForSale: boolean,
	IsLimited: boolean,
	IsLimitedUnique: boolean,
	IsNew: boolean,
	Remaining: number,
	Sales: number,
	Name: string,
	Description: string?,
	PriceInRobux: number,
	Created: string,
	Updated: string,
	ContentRatingTypeId: number,
	MinimumMembershipLevel: number,
	IsPublicDomain: boolean,
}

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
export type GamePassOrDeveloperProductInfo = {
	Creator: CreatorProductInfo,
	ProductId: number,
	IconImageAssetId: number,
	Name: string,
	Description: string?,
	PriceInRobux: number,
	Created: string,
	Updated: string,
	ContentRatingTypeId: number,
	MinimumMembershipLevel: number,
	IsPublicDomain: boolean,
}

--[=[
	Subscription Status

	@interface UserSubscriptonStatus
	.IsSubscribed boolean -- True if the user's subscription is active.
	.IsRenewing boolean -- True if the user is set to renew this subscription after the current subscription period ends.
	@within MarketplaceUtils
]=]
export type UserSubscriptonStatus = {
	IsSubscribed: boolean,
	IsRenewing: boolean,
}

--[=[
	Wraps [MarketplaceService.GetProductInfo] and retrieves information about
	@param assetId number
	@param infoType InfoType | nil
	@return Promise<AssetProductInfo | GamePassOrDeveloperProductInfo>
]=]
function MarketplaceUtils.promiseProductInfo(
	assetId: number,
	infoType: Enum.InfoType
): Promise.Promise<AssetProductInfo | GamePassOrDeveloperProductInfo>
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
	Returns the subscription status

	@param player Player
	@param subscriptionId string
	@return UserSubscriptonStatus
]=]
function MarketplaceUtils.promiseUserSubscriptionStatus(
	player: Player,
	subscriptionId: string
): Promise.Promise<UserSubscriptonStatus>
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(type(subscriptionId) == "string", "Bad subscriptionId")

	return Promise.spawn(function(resolve, reject)
		local subStatus
		local ok, err = pcall(function()
			subStatus = MarketplaceService:GetUserSubscriptionStatusAsync(player, subscriptionId)
		end)
		if not ok then
			return reject(err)
		end
		if type(subStatus) ~= "table" then
			return reject("Bad subStatus type")
		end
		return resolve(subStatus)
	end)
end

--[=[
	Retrieves whether a player owns a gamepass.
	@param userId number
	@param gamePassId number
	@return Promise<boolean>
]=]
function MarketplaceUtils.promiseUserOwnsGamePass(userId: number, gamePassId: number): Promise.Promise<boolean>
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
function MarketplaceUtils.promisePlayerOwnsAsset(player: Player, assetId: number): Promise.Promise<boolean>
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
function MarketplaceUtils.promisePlayerOwnsBundle(player: Player, bundleId: number): Promise.Promise<boolean>
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