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
	Specifies the asset is of type asset. This is basically anything in Roblox's asset id system.
	Think models, UGC, et cetera.

	@prop ASSET string
	@within GameConfigAssetTypes
]=]
	ASSET = "asset";

--[=[
	Bundle asset type

	@prop BUNDLE string
	@within GameConfigAssetTypes
]=]
	BUNDLE = "bundle";

--[=[
	Specifies the asset is of type place
	@prop PLACE string
	@within GameConfigAssetTypes
]=]
	PLACE = "place";

--[=[
	Specifies the asset is of type subscription
	@prop SUBSCRIPTION string
	@within GameConfigAssetTypes
]=]
	SUBSCRIPTION = "subscription";

--[=[
	Specifies the asset is of type membership (Roblox Premium)
	@prop MEMBERSHIP string
	@within GameConfigAssetTypes
]=]
	MEMBERSHIP = "membership";
})