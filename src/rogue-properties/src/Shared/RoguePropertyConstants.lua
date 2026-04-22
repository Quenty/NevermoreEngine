--!nonstrict
--[=[
	@class RoguePropertyConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	INSTANCE_ATTRIBUTE_VALUE = "_DATAMODEL_INSTANCE",
})
