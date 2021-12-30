--[=[
	Provides utility functions involving input objects
	@class InputObjectUtils
]=]

local InputObjectUtils = {}

local MOUSE_USER_INPUT_TYPES = {
	[Enum.UserInputType.MouseButton1] = true;
	[Enum.UserInputType.MouseButton2] = true;
	[Enum.UserInputType.MouseButton3] = true;
	[Enum.UserInputType.MouseWheel] = true;
	[Enum.UserInputType.MouseMovement] = true;
}

--[=[
	Returns whether a user input type involves the mouse.

	@param userInputType UserInputType
	@return true
]=]
function InputObjectUtils.isMouseUserInputType(userInputType)
	assert(typeof(userInputType) == "EnumItem", "Bad userInputType")

	return MOUSE_USER_INPUT_TYPES[userInputType] or false
end

--[=[
	Compares the two input objects and determines if they are the same thing. For example,
	a finger being dragged across a screen, or a mouse input being used as a cursor.

	@param inputObject InputObject
	@param otherInputObject InputObject
	@return boolean
]=]
function InputObjectUtils.isSameInputObject(inputObject, otherInputObject)
	assert(inputObject, "Bad inputObject")
	assert(otherInputObject, "Bad otherInputObject")

	if inputObject == otherInputObject then -- Handles touched events for same finger
		return true
	end

	if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
		return inputObject.UserInputType == otherInputObject.UserInputType
	end

	return false
end

return InputObjectUtils