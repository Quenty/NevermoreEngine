--[=[
	@class GameConfigAssetDataUtils
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetDataUtils = {}

--[=[
	Creates a new asset data
	@param assetType GameConfigAssetType
	@param assetName string
	@param assetId number
	@param iconId number?
	@return GameConfigAssetData
]=]
function GameConfigAssetDataUtils.createAssetData(assetType, assetName, assetId, iconId)
	assert(type(assetType) == "string", "Bad assetType")
	assert(type(assetName) == "string", "Bad assetName")
	assert(type(assetId) == "number", "Bad assetId")
	assert(type(iconId) == "number" or iconId == nil, "Bad iconId") -- Places don't necessarily have an icon

	return {
		assetType = assetType;
		assetName = assetName;
		assetId = assetId;
		iconId = iconId;
	}
end

--[=[
	Verifys that data is asset data
	@param data any
	@return boolean
]=]
function GameConfigAssetDataUtils.isAssetData(data)
	return type(data) == "table"
		and type(data.assetType) == "string"
		and type(data.assetName) == "string"
		and type(data.assetId) == "number"
		and (type(data.iconId) == "number" or type(data.iconId) == "nil")
end

return GameConfigAssetDataUtils