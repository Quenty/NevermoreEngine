--[=[
	@class InputTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local SlottedTouchButtonUtils = require("SlottedTouchButtonUtils")

local InputTypeUtils = {}

--[=[
	A valid input type that can be represented here.
	@type InputType KeyCode | UserInputType | SlottedTouchButton | "TouchButton" | "Tap" | any
	@within InputTypeUtils
]=]

--[=[
	Returns true if the input type is specifying a tap in the world
	@param inputKey any
	@return boolean
]=]
function InputTypeUtils.isTapInWorld(inputKey)
	return inputKey == "Tap"
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

return InputTypeUtils