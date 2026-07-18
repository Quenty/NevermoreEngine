--!strict
--[=[
	@class GameConfigAssetUtils
]=]

local require = require(script.Parent.loader).load(script)

local AttributeUtils = require("AttributeUtils")
local BadgeUtils = require("BadgeUtils")
local Binder = require("Binder")
local GameConfigAssetConstants = require("GameConfigAssetConstants")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local MarketplaceServiceCache = require("MarketplaceServiceCache")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local GameConfigAssetUtils = {}

--[=[
	Creates a new game configuration

	`priority` is only stamped when given; an asset without it reads back as
	[GameConfigAssetConstants.DEFAULT_PRIORITY]. Pass a higher value to win over
	hand-authored assets that share this type and key (see
	[GameConfigPicker.FindFirstActiveAssetOfKey]).

	@param binder Binder<GameConfigAssetBase>
	@param assetType GameConfigAssetType
	@param assetKey string
	@param assetId number
	@param priority number?
	@return Instance
]=]
function GameConfigAssetUtils.create(
	binder: Binder.Binder<any>, -- GameConfigAssetBase.GameConfigAssetBase (require cycle: GameConfigAssetBase requires this module)
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	assetKey: string,
	assetId: number,
	priority: number?
): Folder
	local asset = Instance.new("Folder")
	asset.Name = assetKey

	binder:Bind(asset)

	AttributeUtils.initAttribute(asset, GameConfigAssetConstants.ASSET_TYPE_ATTRIBUTE, assetType)
	AttributeUtils.initAttribute(asset, GameConfigAssetConstants.ASSET_ID_ATTRIBUTE, assetId)
	if priority ~= nil then
		AttributeUtils.initAttribute(asset, GameConfigAssetConstants.PRIORITY_ATTRIBUTE, priority)
	end

	return asset
end

--[=[
	Promises cloud data for a given asset type

	@param serviceBag ServiceBag
	@param assetType GameConfigAssetType
	@param assetId number
	@return Promise<any>
]=]
function GameConfigAssetUtils.promiseCloudDataForAssetType(
	serviceBag: ServiceBag.ServiceBag,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	assetId: number
): Promise.Promise<any>
	assert(type(assetType) == "string", "Bad assetType")
	assert(type(assetId) == "number", "Bad assetId")

	local marketplaceServiceCache: MarketplaceServiceCache.MarketplaceServiceCache =
		serviceBag:GetService(MarketplaceServiceCache) :: any

	-- We really hope this stuff is cached
	if assetType == GameConfigAssetTypes.BADGE then
		return BadgeUtils.promiseBadgeInfo(assetId)
	elseif assetType == GameConfigAssetTypes.PRODUCT then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.Product)
	elseif assetType == GameConfigAssetTypes.PASS then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.GamePass)
	elseif assetType == GameConfigAssetTypes.PLACE then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.Asset)
	elseif assetType == GameConfigAssetTypes.GAME then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.Asset)
	elseif assetType == GameConfigAssetTypes.ASSET then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.Asset)
	elseif assetType == GameConfigAssetTypes.BUNDLE then
		return marketplaceServiceCache:PromiseProductInfo(assetId, Enum.InfoType.Bundle)
	else
		local errorMessage = string.format(
			"[GameConfigAssetUtils.promiseCloudDataForAssetType] - Unknown GameConfigAssetType %q. Ignoring asset.",
			tostring(assetType)
		)

		return Promise.rejected(errorMessage)
	end
end

return GameConfigAssetUtils
