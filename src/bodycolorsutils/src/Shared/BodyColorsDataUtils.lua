--!strict
--[=[
	Utility to transfer and manipulate body colors for a character

	@class BodyColorsDataUtils
]=]

local require = require(script.Parent.loader).load(script)

local Color3Utils = require("Color3Utils")
local Color3SerializationUtils = require("Color3SerializationUtils")
local BodyColorsDataConstants = require("BodyColorsDataConstants")

local BodyColorsDataUtils = {}

--[=[
	Represents body colors data for a humanoid

	@interface BodyColorsData
	.headColor Color3
	.leftArmColor Color3
	.leftLegColor Color3
	.rightArmColor Color3
	.rightLegColor Color3
	.torsoColor Color3
	@within BodyColorsDataUtils
]=]
export type BodyColorsData = {
	headColor: Color3?,
	leftArmColor: Color3?,
	leftLegColor: Color3?,
	rightArmColor: Color3?,
	rightLegColor: Color3?,
	torsoColor: Color3?,
}

--[=[
	Creates a new BodyColorsData
	@param bodyColorsData any
	@return BodyColorsData
]=]
function BodyColorsDataUtils.createBodyColorsData(bodyColorsData: BodyColorsData): BodyColorsData
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")

	return bodyColorsData
end

--[=[
	Returns true if it's a body color data
	@param value any
	@return boolean
]=]
function BodyColorsDataUtils.isBodyColorsData(value: any): boolean
	return type(value) == "table"
		and (typeof(value.headColor) == "Color3" or value.headColor == nil)
		and (typeof(value.leftArmColor) == "Color3" or value.leftArmColor == nil)
		and (typeof(value.leftLegColor) == "Color3" or value.leftLegColor == nil)
		and (typeof(value.rightArmColor) == "Color3" or value.rightArmColor == nil)
		and (typeof(value.rightLegColor) == "Color3" or value.rightLegColor == nil)
		and (typeof(value.torsoColor) == "Color3" or value.torsoColor == nil)
end

--[=[
	Creates a new BodyColorsData from a single color

	@param color3 Color3
	@return BodyColorsData
]=]
function BodyColorsDataUtils.fromUniformColor(color3: Color3): BodyColorsData
	assert(typeof(color3) == "Color3", "Bad color3")

	return BodyColorsDataUtils.createBodyColorsData({
		headColor = color3,
		leftArmColor = color3,
		leftLegColor = color3,
		rightArmColor = color3,
		rightLegColor = color3,
		torsoColor = color3,
	})
end

--[=[
	Creates a new BodyColorsData from a BodyColors instance

	@param bodyColors BodyColors
	@return BodyColorsData
]=]
function BodyColorsDataUtils.fromBodyColors(bodyColors: BodyColors): BodyColorsData
	assert(typeof(bodyColors) == "Instance" and bodyColors:IsA("BodyColors"), "Bad bodyColors")

	return BodyColorsDataUtils.createBodyColorsData({
		headColor = bodyColors.HeadColor3,
		leftArmColor = bodyColors.LeftArmColor3,
		leftLegColor = bodyColors.LeftLegColor3,
		rightArmColor = bodyColors.RightArmColor3,
		rightLegColor = bodyColors.RightLegColor3,
		torsoColor = bodyColors.TorsoColor3,
	})
end

--[=[
	Returns true if the data is a datastore safe body color
	@param value any
	@return boolean
]=]
function BodyColorsDataUtils.isDataStoreSafeBodyColorsData(value: any): boolean
	return type(value) == "table"
		and (Color3SerializationUtils.isSerializedColor3(value.headColor) or value.headColor == nil)
		and (Color3SerializationUtils.isSerializedColor3(value.leftArmColor) or value.leftArmColor == nil)
		and (Color3SerializationUtils.isSerializedColor3(value.leftLegColor) or value.leftLegColor == nil)
		and (Color3SerializationUtils.isSerializedColor3(value.rightArmColor) or value.rightArmColor == nil)
		and (Color3SerializationUtils.isSerializedColor3(value.rightLegColor) or value.rightLegColor == nil)
		and (Color3SerializationUtils.isSerializedColor3(value.torsoColor) or value.torsoColor == nil)
end

export type DataStoreSafeBodyColorsData = {
	headColor: Color3SerializationUtils.SerializedColor3?,
	leftArmColor: Color3SerializationUtils.SerializedColor3?,
	leftLegColor: Color3SerializationUtils.SerializedColor3?,
	rightArmColor: Color3SerializationUtils.SerializedColor3?,
	rightLegColor: Color3SerializationUtils.SerializedColor3?,
	torsoColor: Color3SerializationUtils.SerializedColor3?,
}

--[=[
	Gets a datastore safe version of body color
	@param bodyColorsData BodyColorsData
	@return DataStoreSafeBodyColorsData
]=]
function BodyColorsDataUtils.toDataStoreSafeBodyColorsData(bodyColorsData: BodyColorsData): DataStoreSafeBodyColorsData
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")

	return {
		headColor = bodyColorsData.headColor and Color3SerializationUtils.serialize(bodyColorsData.headColor) or nil,
		leftArmColor = bodyColorsData.leftArmColor and Color3SerializationUtils.serialize(bodyColorsData.leftArmColor)
			or nil,
		leftLegColor = bodyColorsData.leftLegColor and Color3SerializationUtils.serialize(bodyColorsData.leftLegColor)
			or nil,
		rightArmColor = bodyColorsData.rightArmColor and Color3SerializationUtils.serialize(
			bodyColorsData.rightArmColor
		) or nil,
		rightLegColor = bodyColorsData.rightLegColor and Color3SerializationUtils.serialize(
			bodyColorsData.rightLegColor
		) or nil,
		torsoColor = bodyColorsData.torsoColor and Color3SerializationUtils.serialize(bodyColorsData.torsoColor) or nil,
	}
end

--[=[
	Constructs a BodyColorsData from a datastore safe body color
	@param data DataStoreSafeBodyColorsData
	@return BodyColorsData
]=]
function BodyColorsDataUtils.fromDataStoreSafeBodyColorsData(data: DataStoreSafeBodyColorsData): BodyColorsData
	assert(BodyColorsDataUtils.isDataStoreSafeBodyColorsData(data), "Bad dataStoreSafeBodyColorsData")

	return BodyColorsDataUtils.createBodyColorsData({
		headColor = data.headColor and Color3SerializationUtils.deserialize(data.headColor) or nil,
		leftArmColor = data.leftArmColor and Color3SerializationUtils.deserialize(data.leftArmColor) or nil,
		leftLegColor = data.leftLegColor and Color3SerializationUtils.deserialize(data.leftLegColor) or nil,
		rightArmColor = data.rightArmColor and Color3SerializationUtils.deserialize(data.rightArmColor) or nil,
		rightLegColor = data.rightLegColor and Color3SerializationUtils.deserialize(data.rightLegColor) or nil,
		torsoColor = data.torsoColor and Color3SerializationUtils.deserialize(data.torsoColor) or nil,
	})
end

--[=[
	Constructs a BodyColorsData from a humanoidDescription

	@param humanoidDescription HumanoidDescription
	@return BodyColorsData
]=]
function BodyColorsDataUtils.fromHumanoidDescription(humanoidDescription: HumanoidDescription): BodyColorsData
	assert(
		typeof(humanoidDescription) == "Instance" and humanoidDescription:IsA("HumanoidDescription"),
		"Bad humanoidDescription"
	)

	return BodyColorsDataUtils.createBodyColorsData({
		headColor = humanoidDescription.HeadColor,
		leftArmColor = humanoidDescription.LeftArmColor,
		leftLegColor = humanoidDescription.LeftLegColor,
		rightArmColor = humanoidDescription.RightArmColor,
		rightLegColor = humanoidDescription.RightLegColor,
		torsoColor = humanoidDescription.TorsoColor,
	})
end

--[=[
	Returns if the body colors data represents one solid color for all body parts.

	@param bodyColorsData BodyColorsData
	@return boolean
]=]
function BodyColorsDataUtils.isUniformColor(bodyColorsData: BodyColorsData): boolean
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")

	local headColor = bodyColorsData.headColor
	if headColor == nil then
		return false
	end

	if bodyColorsData.leftArmColor == nil or not Color3Utils.areEqual(headColor, bodyColorsData.leftArmColor) then
		return false
	end

	if bodyColorsData.leftLegColor == nil or not Color3Utils.areEqual(headColor, bodyColorsData.leftLegColor) then
		return false
	end

	if bodyColorsData.rightArmColor == nil or not Color3Utils.areEqual(headColor, bodyColorsData.rightArmColor) then
		return false
	end

	if bodyColorsData.rightLegColor == nil or not Color3Utils.areEqual(headColor, bodyColorsData.rightLegColor) then
		return false
	end

	if bodyColorsData.torsoColor == nil or not Color3Utils.areEqual(headColor, bodyColorsData.torsoColor) then
		return false
	end

	return true
end

function BodyColorsDataUtils.getUniformColor(bodyColorsData): Color3?
	if BodyColorsDataUtils.isUniformColor(bodyColorsData) then
		return bodyColorsData.headColor
	end

	return nil
end

--[=[
	Constructs a BodyColors from the bodyColorsData

	@param bodyColorsData BodyColorsData
	@return BodyColors
]=]
function BodyColorsDataUtils.toBodyColors(bodyColorsData: BodyColorsData): BodyColors
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")

	local bodyColors = Instance.new("BodyColors")
	BodyColorsDataUtils.applyToBodyColors(bodyColorsData, bodyColors)

	return bodyColors
end

--[=[
	Applies body colors to the actual body color property

	@param bodyColorsData BodyColorsData
	@param bodyColors BodyColors
	@return BodyColors
]=]
function BodyColorsDataUtils.applyToBodyColors(bodyColorsData: BodyColorsData, bodyColors: BodyColors)
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")
	assert(typeof(bodyColors) == "Instance" and bodyColors:IsA("BodyColors"), "Bad bodyColors")

	if bodyColorsData.headColor then
		bodyColors.HeadColor3 = bodyColorsData.headColor
	end

	if bodyColorsData.leftArmColor then
		bodyColors.LeftArmColor3 = bodyColorsData.leftArmColor
	end

	if bodyColorsData.leftLegColor then
		bodyColors.LeftLegColor3 = bodyColorsData.leftLegColor
	end

	if bodyColorsData.rightArmColor then
		bodyColors.RightArmColor3 = bodyColorsData.rightArmColor
	end

	if bodyColorsData.rightLegColor then
		bodyColors.RightLegColor3 = bodyColorsData.rightLegColor
	end

	if bodyColorsData.torsoColor then
		bodyColors.TorsoColor3 = bodyColorsData.torsoColor
	end
end

--[=[
	Extracts body colors from attributes
	@param instance Instance
	@return BodyColorsData
]=]
function BodyColorsDataUtils.fromAttributes(instance: Instance): BodyColorsData
	assert(typeof(instance) == "Instance", "Bad instance")

	local bodyColorsData = {}

	for key, attributeName in BodyColorsDataConstants.ATTRIBUTE_MAPPING do
		local value = instance:GetAttribute(attributeName)
		if value ~= nil then
			if typeof(value) == "Color3" then
				bodyColorsData[key] = value
			else
				warn(
					string.format(
						"[BodyColorsDataUtils.fromAttributes] - Bad attribute %q of type %q",
						attributeName,
						typeof(value)
					)
				)
			end
		end
	end

	return BodyColorsDataUtils.createBodyColorsData(bodyColorsData)
end

--[=[
	Sets attributes to store body colors.
	@param instance Instance
	@param bodyColorsData BodyColorsData
]=]
function BodyColorsDataUtils.setAttributes(instance: Instance, bodyColorsData: BodyColorsData)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")

	for key, attributeName in BodyColorsDataConstants.ATTRIBUTE_MAPPING do
		local value = bodyColorsData[key]
		if value then
			instance:SetAttribute(attributeName, value)
		else
			instance:SetAttribute(attributeName, nil)
		end
	end
end

--[=[
	Applies body colors to the actual body color property

	@param bodyColorsData BodyColorsData
	@param humanoidDescription HumanoidDescription
	@return BodyColors
]=]
function BodyColorsDataUtils.applyToHumanoidDescription(bodyColorsData: BodyColorsData, humanoidDescription: HumanoidDescription)
	assert(BodyColorsDataUtils.isBodyColorsData(bodyColorsData), "Bad bodyColorsData")
	assert(typeof(humanoidDescription) == "Instance" and humanoidDescription:IsA("HumanoidDescription"), "Bad humanoidDescription")

	if bodyColorsData.headColor then
		humanoidDescription.HeadColor = bodyColorsData.headColor
	end

	if bodyColorsData.leftArmColor then
		humanoidDescription.LeftArmColor = bodyColorsData.leftArmColor
	end

	if bodyColorsData.leftLegColor then
		humanoidDescription.LeftLegColor = bodyColorsData.leftLegColor
	end

	if bodyColorsData.rightArmColor then
		humanoidDescription.RightArmColor = bodyColorsData.rightArmColor
	end

	if bodyColorsData.rightLegColor then
		humanoidDescription.RightLegColor = bodyColorsData.rightLegColor
	end

	if bodyColorsData.torsoColor then
		humanoidDescription.TorsoColor = bodyColorsData.torsoColor
	end
end

return BodyColorsDataUtils