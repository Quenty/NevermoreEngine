--[=[
	@class RoundingBehaviourTypes
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	RoundToClosest = "roundToClosest";
	Truncate = "truncate";
})