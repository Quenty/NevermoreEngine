--!strict
--[=[
	@class InputTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local SlottedTouchButtonUtils = (require :: any)("SlottedTouchButtonUtils")
local Set = require("Set")

local InputTypeUtils = {}

--[=[
	A valid input type that can be represented here.
	@type InputType KeyCode | UserInputType | SlottedTouchButton | "TouchButton" | "Tap" | "Drag" | any
	@within InputTypeUtils
]=]
export type InputType = Enum.UserInputType | Enum.KeyCode | string | SlottedTouchButton | "TouchButton" | "Tap" | "Drag"

--[=[
	A touch button that goes into a specific slot. This ensures
	consistent slot positions.

	@interface SlottedTouchButton
	.type "SlottedTouchButton"
	.slotId string
	@within InputTypeUtils
]=]
export type SlottedTouchButton = {
	type: "SlottedTouchButton",
	slotId: string,
}

--[=[
	Returns true if the input type is a known input type
	@param inputType any
	@return boolean
]=]
function InputTypeUtils.isKnownInputType(inputType: any): boolean
	return InputTypeUtils.isTapInWorld(inputType)
		or InputTypeUtils.isRobloxTouchButton(inputType)
		or InputTypeUtils.isDrag(inputType)
		or SlottedTouchButtonUtils.isSlottedTouchButton(inputType)
		or (
			typeof(inputType) == "EnumItem"
			and (tostring(inputType.EnumType) == "UserInputType" or tostring(inputType.EnumType) == "KeyCode")
		)
end

--[=[
	Returns true if the input type is specifying a tap in the world
	@param inputKey any
	@return boolean
]=]
function InputTypeUtils.isTapInWorld(inputKey: InputType): boolean
	return inputKey == "Tap"
end

--[=[
	Returns true if the input type is specifying a drag
	@param inputKey any
	@return boolean
]=]
function InputTypeUtils.isDrag(inputKey: InputType): boolean
	return inputKey == "Drag"
end

--[=[
	Returns true if the input type is specifying a Roblox touch button
	@param inputKey any
	@return boolean
]=]
function InputTypeUtils.isRobloxTouchButton(inputKey: InputType): boolean
	return inputKey == "TouchButton"
end

--[=[
	Specifies a tap in the world
	@return "Tap"
]=]
function InputTypeUtils.createTapInWorld(): "Tap"
	return "Tap"
end

--[=[
	Specifies a roblox touch button
	@return "Tap"
]=]
function InputTypeUtils.createRobloxTouchButton(): "TouchButton"
	return "TouchButton"
end

--[=[
	Computes a unique id for an inputType which can be used
	in a set to deduplicate/compare the objects. Used to know
	when to exclude different types from each other.

	@param inputType InputType
	@return any
]=]
function InputTypeUtils.getUniqueKeyForInputType(inputType: InputType): any
	if SlottedTouchButtonUtils.isSlottedTouchButton(inputType) then
		return (inputType :: any).slotId
	else
		return inputType
	end
end

local function convertValuesToJSONIfNeeded(list)
	local result = {}
	for key, value in list do
		if type(value) == "table" then
			result[key] = HttpService:JSONEncode(value)
		else
			result[key] = value
		end
	end
	return result
end

--[=[
	Expensive comparison check to see if InputTypes are the same or not.

	@param a { InputType }
	@param b { InputType }
	@return boolean
]=]
function InputTypeUtils.areInputTypesListsEquivalent(a: { InputType }, b: { InputType }): boolean
	-- allocate, hehe
	local setA = Set.fromTableValue(convertValuesToJSONIfNeeded(a))
	local setB = Set.fromTableValue(convertValuesToJSONIfNeeded(b))

	local remaining = Set.difference(setA, setB)
	local left = Set.toList(remaining)
	return #left == 0
end

return InputTypeUtils