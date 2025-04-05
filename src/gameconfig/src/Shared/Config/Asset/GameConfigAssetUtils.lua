--[=[
	@class GameConfigAssetUtils
]=]

local require = require(script.Parent.loader).load(script)

local AttributeUtils = require("AttributeUtils")
local GameConfigAssetConstants = require("GameConfigAssetConstants")
local BadgeUtils = require("BadgeUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local MarketplaceServiceCache = require("MarketplaceServiceCache")
local Promise = require("Promise")
local _ServiceBag = require("ServiceBag")

local GameConfigAssetUtils = {}

--[=[
	Creates a new game configuration
	@param binder Binder<GameConfigAssetBase>
	@param assetType GameConfigAssetType
	@param assetKey string
	@param assetId number
	@return Instance
]=]
function GameConfigAssetUtils.create(
	binder,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	assetKey: string,
	assetId: number
): Folder
	local asset = Instance.new("Folder")
	asset.Name = assetKey

	binder:Bind(asset)

	AttributeUtils.initAttribute(asset, GameConfigAssetConstants.ASSET_TYPE_ATTRIBUTE, assetType)
	AttributeUtils.initAttribute(asset, GameConfigAssetConstants.ASSET_ID_ATTRIBUTE, assetId)

	return asset
end

--[=[
	Promises cloud data for a given asset type

	@param serviceBag ServiceBag
	@param assetType GameConfigAssetType
	@param assetId number
	@return Promise<any>
]=]
function GameConfigAssetUtils.promiseCloudDataForAssetType(serviceBag: _ServiceBag.ServiceBag, assetType: GameConfigAssetTypes.GameConfigAssetType, assetId: number): Promise.Promise<any>
	assert(type(assetType) == "string", "Bad assetType")
	assert(type(assetId) == "number", "Bad assetId")

	local marketplaceServiceCache = serviceBag:GetService(MarketplaceServiceCache)

	-- We really hope this stuff is cached
	if assetType == GameConfigAssetTypes.BADGE then
		return BadgeUtils.promiseBadgeInfo(assetId)
	elseif assetType == GameConfigAssetTypes.PRODUCT then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.Product)
	elseif assetType == GameConfigAssetTypes.PASS then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.GamePass)
	elseif assetType == GameConfigAssetTypes.PLACE then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.Asset)
	elseif assetType == GameConfigAssetTypes.ASSET then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.Asset)
	elseif assetType == GameConfigAssetTypes.BUNDLE then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.Bundle)
	else
		local errorMessage = string.format("[GameConfigAssetUtils.promiseCloudDataForAssetType] - Unknown GameConfigAssetType %q. Ignoring asset.",
			tostring(assetType))

		return Promise.rejected(errorMessage)
	end
end

return GameConfigAssetUtils