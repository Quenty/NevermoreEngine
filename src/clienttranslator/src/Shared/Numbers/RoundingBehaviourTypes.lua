--!strict
--[=[
	@class RoundingBehaviourTypes
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

export type RoundingBehaviourType = "roundToClosest" | "truncate" | "None"

export type RoundingBehaviourTypeMap = {
	ROUND_TO_CLOSEST: "roundToClosest",
	TRUNCATE: "truncate",
	NONE: "none",
}

return Table.readonly({
	ROUND_TO_CLOSEST = "roundToClosest",
	TRUNCATE = "truncate",
	NONE = "none",
} :: RoundingBehaviourTypeMap)
