--!nonstrict
--[=[
	@class RoguePropertyBaseValueTypes
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	INSTANCE = "instance",
	ANY = "any",
})
