--[=[
	@class GameConfigAssetConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	ASSET_TYPE_ATTRIBUTE = "AssetType";
	ASSET_ID_ATTRIBUTE = "AssetId";
})