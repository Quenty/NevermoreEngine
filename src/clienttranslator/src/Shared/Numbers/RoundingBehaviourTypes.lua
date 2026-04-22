--!strict
--[=[
	@class RoundingBehaviourTypes
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type RoundingBehaviourType = "roundToClosest" | "truncate" | "None"

return SimpleEnum.new({
	ROUND_TO_CLOSEST = "roundToClosest" :: "roundToClosest",
	TRUNCATE = "truncate" :: "truncate",
	NONE = "none" :: "none",
})
