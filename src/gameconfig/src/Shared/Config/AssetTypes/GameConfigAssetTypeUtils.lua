--!strict
--[=[
	@class GameConfigAssetTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")

local GameConfigAssetTypeUtils = {}

local pluralMap: { [GameConfigAssetTypes.GameConfigAssetType]: string } = {
	[GameConfigAssetTypes.BADGE] = "badges",
	[GameConfigAssetTypes.PRODUCT] = "products",
	[GameConfigAssetTypes.PASS] = "passes",
	[GameConfigAssetTypes.PLACE] = "places",
	[GameConfigAssetTypes.ASSET] = "assets",
	[GameConfigAssetTypes.BUNDLE] = "bundles",
	[GameConfigAssetTypes.SUBSCRIPTION] = "subscriptions",
	[GameConfigAssetTypes.MEMBERSHIP] = "memberships",
}

for _, item: any in GameConfigAssetTypes do
	assert(pluralMap[item], "Missing plural")
end

--[=[
	Returns true if the asset type is valid

	@param assetType any
	@return boolean
]=]
function GameConfigAssetTypeUtils.isAssetType(assetType: any): boolean
	return type(assetType) == "string" and pluralMap[assetType :: any] ~= nil
end

--[=[
	Gets the plural version of the asset type for instance naming

	@param assetType GameConfigAssetType
	@return string
]=]
function GameConfigAssetTypeUtils.getPlural(assetType: GameConfigAssetTypes.GameConfigAssetType): string
	return pluralMap[assetType] or error("Bad assetType")
end

return GameConfigAssetTypeUtils
