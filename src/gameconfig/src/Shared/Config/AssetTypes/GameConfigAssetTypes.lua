--[=[
	@class GameConfigAssetTypes
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
--[=[
	Specifies the asset is of type badge
	@prop BADGE string
	@within GameConfigAssetTypes
]=]
	BADGE = "badge";

--[=[
	Specifies the asset is of type product
	@prop PRODUCT string
	@within GameConfigAssetTypes
]=]
	PRODUCT = "product";

--[=[
	Specifies the asset is of type pass
	@prop PASS string
	@within GameConfigAssetTypes
]=]
	PASS = "pass";

--[=[
	Specifies the asset is of type place
	@prop PLACE string
	@within GameConfigAssetTypes
]=]
	PLACE = "place";
})