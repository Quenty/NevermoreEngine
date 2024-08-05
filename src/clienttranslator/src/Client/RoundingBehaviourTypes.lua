--[=[
	@class RoundingBehaviourTypes
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	ROUND_TO_CLOSEST = "roundToClosest";
	TRUNCATE = "truncate";
	NONE = "None"
})