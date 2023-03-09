--[=[
	Utility to transfer and manipulate body colors for a character

	@class BodyColorsDataUtils
]=]

local require = require(script.Parent.loader).load(script)

local Color3Utils = require("Color3Utils")

local BodyColorsDataUtils = {}

--[=[
	Represents body colors data for a humanoid

	@interface BodyColorsData
	.HeadColor3 Color3
	.LeftArmColor3 Color3
	.LeftLegColor3 Color3
	.RightArmColor3 Color3
	.RightLegColor3 Color3
	.TorsoColor3 Color3
	@within BodyColorsDataUtils
]=]

--[=[
	Creates a new BodyColorsData
	@param data any
	@return BodyColorsData
]=]
function BodyColorsDataUtils.createBodyColorsData(bodyColorsData)
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")

	return bodyColorsData
end

--[=[
	Returns true if it's a body color data
	@param value any
	@return boolean
]=]
function BodyColorsDataUtils.isBodyColorsData(value)
	return type(value) == "table"
		and (typeof(value.HeadColor3) == "Color3" or value.HeadColor3 == nil)
		and (typeof(value.LeftArmColor3) == "Color3" or value.LeftArmColor3 == nil)
		and (typeof(value.LeftLegColor3) == "Color3" or value.LeftLegColor3 == nil)
		and (typeof(value.RightArmColor3) == "Color3" or value.RightArmColor3 == nil)
		and (typeof(value.RightLegColor3) == "Color3" or value.RightLegColor3 == nil)
		and (typeof(value.TorsoColor3) == "Color3" or value.TorsoColor3 == nil)
end

--[=[
	Creates a new BodyColorsData from a single color

	@param data any
	@return BodyColorsData
]=]
function BodyColorsDataUtils.fromSingleColor(color3)
	assert(typeof(color3) == "Color3", "Bad color3")

	return BodyColorsDataUtils.createBodyColorsData({
		HeadColor3 = color3;
		LeftArmColor3 = color3;
		LeftLegColor3 = color3;
		RightArmColor3 = color3;
		RightLegColor3 = color3;
		TorsoColor3 = color3;
	})
end

--[=[
	Creates a new BodyColorsData from a BodyColors instance

	@param bodyColors BodyColors
	@return BodyColorsData
]=]
function BodyColorsDataUtils.fromBodyColors(bodyColors)
	assert(typeof(bodyColors) == "Instance" and bodyColors:IsA("BodyColors"), "Bad bodyColors")

	return BodyColorsDataUtils.createBodyColorsData({
		HeadColor3 = bodyColors.HeadColor3;
		LeftArmColor3 = bodyColors.LeftArmColor3;
		LeftLegColor3 = bodyColors.LeftLegColor3;
		RightArmColor3 = bodyColors.RightArmColor3;
		RightLegColor3 = bodyColors.RightLegColor3;
		TorsoColor3 = bodyColors.TorsoColor3;
	})
end

--[=[
	Constructs a BodyColorsData from a humanoidDescription

	@param humanoidDescription HumanoidDescription
	@return BodyColorsData
]=]
function BodyColorsDataUtils.fromHumanoidDescription(humanoidDescription)
	assert(typeof(humanoidDescription) == "Instance" and humanoidDescription:IsA("HumanoidDescription"), "Bad humanoidDescription")

	return BodyColorsDataUtils.createBodyColorsData({
		HeadColor3 = humanoidDescription.HeadColor;
		LeftArmColor3 = humanoidDescription.LeftArmColor;
		LeftLegColor3 = humanoidDescription.LeftLegColor;
		RightArmColor3 = humanoidDescription.RightArmColor;
		RightLegColor3 = humanoidDescription.RightLegColor;
		TorsoColor3 = humanoidDescription.TorsoColor;
	})
end

--[=[
	Returns if the body colors data represents one solid color for all body parts.

	@param bodyColorsData BodyColorsData
	@return boolean
]=]
function BodyColorsDataUtils.isSingleColor(bodyColorsData)
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")

	local headColor = bodyColorsData.HeadColor3
	if headColor == nil then
		return false
	end

	if bodyColorsData.LeftArmColor3 == nil or not Color3Utils.areEqual(headColor, bodyColorsData.LeftArmColor3) then
		return false
	end

	if bodyColorsData.LeftLegColor3 == nil or not Color3Utils.areEqual(headColor, bodyColorsData.LeftLegColor3) then
		return false
	end

	if bodyColorsData.RightArmColor3 == nil or not Color3Utils.areEqual(headColor, bodyColorsData.RightArmColor3) then
		return false
	end

	if bodyColorsData.RightLegColor3 == nil or not Color3Utils.areEqual(headColor, bodyColorsData.RightLegColor3) then
		return false
	end

	if bodyColorsData.TorsoColor3 == nil or not Color3Utils.areEqual(headColor, bodyColorsData.TorsoColor3) then
		return false
	end

	return true
end

--[=[
	Constructs a BodyColors from the bodyColorsData

	@param bodyColorsData BodyColorsData
	@return BodyColors
]=]
function BodyColorsDataUtils.toBodyColors(bodyColorsData)
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")

	local bodyColors = Instance.new("BodyColors")
	BodyColorsDataUtils.applyToBodyColors(bodyColors, bodyColorsData)

	return bodyColors
end

--[=[
	Applies body colors to the actual body color property

	@param bodyColors BodyColors
	@param bodyColorsData BodyColorsData
	@return BodyColors
]=]
function BodyColorsDataUtils.applyToBodyColors(bodyColors, bodyColorsData)
	assert(typeof(bodyColors) == "Instance" and bodyColors:IsA("BodyColors"), "Bad bodyColors")
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")

	if bodyColorsData.HeadColor3 then
		bodyColors.HeadColor3 = bodyColorsData.HeadColor3
	end

	if bodyColorsData.LeftArmColor3 then
		bodyColors.LeftArmColor3 = bodyColorsData.LeftArmColor3
	end

	if bodyColorsData.LeftLegColor3 then
		bodyColors.LeftLegColor3 = bodyColorsData.LeftLegColor3
	end

	if bodyColorsData.RightArmColor3 then
		bodyColors.RightArmColor3 = bodyColorsData.RightArmColor3
	end

	if bodyColorsData.RightLegColor3 then
		bodyColors.RightLegColor3 = bodyColorsData.RightLegColor3
	end

	if bodyColorsData.TorsoColor3 then
		bodyColors.TorsoColor3 = bodyColorsData.TorsoColor3
	end
end

--[=[
	Applies body colors to the actual body color property

	@param bodyColors BodyColors
	@param bodyColorsData BodyColorsData
	@return BodyColors
]=]
function BodyColorsDataUtils.applyToHumanoidDescription(humanoidDescription, bodyColorsData)
	assert(typeof(humanoidDescription) == "Instance" and humanoidDescription:IsA("HumanoidDescription"), "Bad humanoidDescription")
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")

	if bodyColorsData.HeadColor3 then
		humanoidDescription.HeadColor = bodyColorsData.HeadColor3
	end

	if bodyColorsData.LeftArmColor3 then
		humanoidDescription.LeftArmColor = bodyColorsData.LeftArmColor3
	end

	if bodyColorsData.LeftLegColor3 then
		humanoidDescription.LeftLegColor = bodyColorsData.LeftLegColor3
	end

	if bodyColorsData.RightArmColor3 then
		humanoidDescription.RightArmColor = bodyColorsData.RightArmColor3
	end

	if bodyColorsData.RightLegColor3 then
		humanoidDescription.RightLegColor = bodyColorsData.RightLegColor3
	end

	if bodyColorsData.TorsoColor3 then
		humanoidDescription.TorsoColor = bodyColorsData.TorsoColor3
	end
end

return BodyColorsDataUtils