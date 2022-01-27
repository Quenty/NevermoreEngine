--[=[
	@class GameConfigAssetUtils
]=]

local require = require(script.Parent.loader).load(script)

local AttributeUtils = require("AttributeUtils")
local GameConfigAssetConstants = require("GameConfigAssetConstants")

local GameConfigAssetUtils = {}

function GameConfigAssetUtils.create(binder, assetType, assetKey, assetId)
	local asset = Instance.new("Folder")
	asset.Name = assetKey

	binder:Bind(asset)

	AttributeUtils.initAttribute(asset, GameConfigAssetConstants.ASSET_TYPE_ATTRIBUTE, assetType)
	AttributeUtils.initAttribute(asset, GameConfigAssetConstants.ASSET_ID_ATTRIBUTE, assetId)

	return asset
end

return GameConfigAssetUtils