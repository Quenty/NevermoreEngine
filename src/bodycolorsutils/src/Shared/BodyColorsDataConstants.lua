--[=[
	@class BodyColorsDataConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	ATTRIBUTE_MAPPING = {
		headColor = "HeadColor";
		leftArmColor = "LeftArmColor";
		leftLegColor = "LeftLegColor";
		rightArmColor = "RightArmColor";
		rightLegColor = "RightLegColor";
		torsoColor = "TorsoColor";
	};
})