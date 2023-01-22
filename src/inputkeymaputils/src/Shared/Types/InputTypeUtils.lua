--[=[
	@class InputTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local SlottedTouchButtonUtils = require("SlottedTouchButtonUtils")
local Set = require("Set")

local InputTypeUtils = {}

--[=[
	A valid input type that can be represented here.
	@type InputType KeyCode | UserInputType | SlottedTouchButton | "TouchButton" | "Tap" | "Drag" | any
	@within InputTypeUtils
]=]

function InputTypeUtils.isKnownInputType(inputType)
	return InputTypeUtils.isTapInWorld(inputType)
		or InputTypeUtils.isRobloxTouchButton(inputType)
		or InputTypeUtils.isDrag(inputType)
		or SlottedTouchButtonUtils.isSlottedTouchButton(inputType)
		or (typeof(inputType) == "EnumItem" and (
			tostring(inputType.EnumType) == "UserInputType"
			or tostring(inputType.EnumType) == "KeyCode"))
end

--[=[
	Returns true if the input type is specifying a tap in the world
	@param inputKey any
	@return boolean
]=]
function InputTypeUtils.isTapInWorld(inputKey)
	return inputKey == "Tap"
end


--[=[
	Returns true if the input type is specifying a drag
	@param inputKey any
	@return boolean
]=]
function InputTypeUtils.isDrag(inputKey)
	return inputKey == "Drag"
end

--[=[
	Returns true if the input type is specifying a Roblox touch button
	@param inputKey any
	@return boolean
]=]
function InputTypeUtils.isRobloxTouchButton(inputKey)
	return inputKey == "TouchButton"
end

--[=[
	Specifies a tap in the world
	@return "Tap"
]=]
function InputTypeUtils.createTapInWorld()
	return "Tap"
end

--[=[
	Specifies a roblox touch button
	@return "Tap"
]=]
function InputTypeUtils.createRobloxTouchButton()
	return "TouchButton"
end

--[=[
	Computes a unique id for an inputType which can be used
	in a set to deduplicate/compare the objects. Used to know
	when to exclude different types from each other.

	@param inputType InputType
	@return any
]=]
function InputTypeUtils.getUniqueKeyForInputType(inputType)
	if SlottedTouchButtonUtils.isSlottedTouchButton(inputType) then
		return inputType.slotId
	else
		return inputType
	end
end

local function convertValuesToJSONIfNeeded(list)
	local result = {}
	for key, value in pairs(list) do
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
function InputTypeUtils.areInputTypesListsEquivalent(a, b)
	-- allocate, hehe
	local setA = Set.fromTableValue(convertValuesToJSONIfNeeded(a))
	local setB = Set.fromTableValue(convertValuesToJSONIfNeeded(b))

	local remaining = Set.difference(setA, setB)
	local left = Set.toList(remaining)
	return #left == 0
end

return InputTypeUtils