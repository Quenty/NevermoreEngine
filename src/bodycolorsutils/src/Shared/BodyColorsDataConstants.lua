--!strict
--[=[
	@class BodyColorsDataConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

local ATTRIBUTE_MAPPING: { [string]: string } = {
	headColor = "HeadColor",
	leftArmColor = "LeftArmColor",
	leftLegColor = "LeftLegColor",
	rightArmColor = "RightArmColor",
	rightLegColor = "RightLegColor",
	torsoColor = "TorsoColor",
}

return Table.readonly({
	ATTRIBUTE_MAPPING = ATTRIBUTE_MAPPING,
})
