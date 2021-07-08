--- Provides utility functions involving input objects
-- @module InputObjectUtils

local InputObjectUtils = {}

local MOUSE_USER_INPUT_TYPES = {
	[Enum.UserInputType.MouseButton1] = true;
	[Enum.UserInputType.MouseButton2] = true;
	[Enum.UserInputType.MouseButton3] = true;
	[Enum.UserInputType.MouseWheel] = true;
	[Enum.UserInputType.MouseMovement] = true;
}

function InputObjectUtils.isMouseUserInputType(userInputType)
	assert(typeof(userInputType) == "EnumItem")

	return MOUSE_USER_INPUT_TYPES[userInputType]
end

function InputObjectUtils.isSameInputObject(inputObject, otherInputObject)
	assert(inputObject)
	assert(otherInputObject)

	if inputObject == otherInputObject then -- Handles touched events for same finger
		return true
	end

	if InputObjectUtils.isMouseUserInputType(inputObject.UserInputType) then
		return inputObject.UserInputType == otherInputObject.UserInputType
	end

	return false
end

return InputObjectUtils