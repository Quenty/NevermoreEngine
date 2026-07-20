--!strict
--[=[
	@class GameConfigAssetConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	ASSET_TYPE_ATTRIBUTE = "AssetType",
	ASSET_ID_ATTRIBUTE = "AssetId",
	-- Higher wins when several active assets share a type and key. Absent means
	-- the default, DEFAULT_PRIORITY -- so hand-authored assets (which never set
	-- it) are beaten by a higher-priority one registered in code.
	PRIORITY_ATTRIBUTE = "Priority",
	DEFAULT_PRIORITY = 0,
})
