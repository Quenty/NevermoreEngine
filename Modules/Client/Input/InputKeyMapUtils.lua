--- Utility methods for input map
-- @module InputKeyMapUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Set = require("Set")

local InputKeyMapUtils = {}

function InputKeyMapUtils.createKeyMap(inputMode, inputTypes)
	assert(type(inputMode) == "table")
	assert(type(inputTypes) == "table")

	return {
		inputMode = inputMode;
		inputTypes = inputTypes;
	}
end

function InputKeyMapUtils.getInputTypesSetForActionBinding(inputKeyMapList)
	return Set.fromList(InputKeyMapUtils.getInputTypesForActionBinding(inputKeyMapList))
end

--- Converts keymap into ContextActionService friendly types
function InputKeyMapUtils.getInputTypesForActionBinding(inputKeyMapList)
	assert(type(inputKeyMapList) == "table", "inputKeyMap must be a table")
	local types = {}

	for _, inputKeyMap in pairs(inputKeyMapList) do
		assert(inputKeyMap.inputMode)
		assert(inputKeyMap.inputTypes)

		for _, _type in pairs(inputKeyMap.inputTypes) do
			if typeof(_type) == "EnumItem" then
				table.insert(types, _type)
			end
		end
	end

	return types
end

function InputKeyMapUtils.isTouchButton(inputKeyMapList)
	for _, inputKeyMap in pairs(inputKeyMapList) do
		assert(inputKeyMap.inputMode)
		assert(inputKeyMap.inputTypes)

		for _, _type in pairs(inputKeyMap.inputTypes) do
			if _type == "TouchButton" then
				return true
			end
		end
	end

	return false
end

function InputKeyMapUtils.isTapInWorld(inputKeyMapList)
	assert(type(inputKeyMapList) == "table", "inputKeyMap must be a table")

	for _, inputKeyMap in pairs(inputKeyMapList) do
		assert(inputKeyMap.inputMode)
		assert(inputKeyMap.inputTypes)

		for _, _type in pairs(inputKeyMap.inputTypes) do
			if _type == "Tap" then
				return true
			end
		end
	end

	return false
end

return InputKeyMapUtils