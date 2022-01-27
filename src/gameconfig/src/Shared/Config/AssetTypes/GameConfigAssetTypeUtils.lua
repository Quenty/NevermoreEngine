--[=[
	@class GameConfigAssetTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")

local GameConfigAssetTypeUtils = {}

local pluralMap = {
	[GameConfigAssetTypes.BADGE] = "badges";
	[GameConfigAssetTypes.PRODUCT] = "products";
	[GameConfigAssetTypes.PASS] = "passes";
	[GameConfigAssetTypes.PLACE] = "places";
}

for _, item in pairs(GameConfigAssetTypes) do
	assert(pluralMap[item], "Missing plural")
end

function GameConfigAssetTypeUtils.isAssetType(assetType)
	return type(assetType) == "string" and pluralMap[assetType] ~= nil
end

function GameConfigAssetTypeUtils.getPlural(assetType)
	return pluralMap[assetType] or error("Bad assetType")
end

return GameConfigAssetTypeUtils