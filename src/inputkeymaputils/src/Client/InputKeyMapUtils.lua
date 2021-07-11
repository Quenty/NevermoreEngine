--- Utility methods for input map
-- @module InputKeyMapUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Set = require("Set")
local Table = require("Table")

local InputKeyMapUtils = {}

function InputKeyMapUtils.createKeyMap(inputMode, inputTypes)
	assert(type(inputMode) == "table")
	assert(type(inputTypes) == "table")

	return Table.readonly({
		inputMode = inputMode;
		inputTypes = inputTypes;
	})
end

function InputKeyMapUtils.getInputTypesSetForActionBinding(inputKeyMapList)
	return Set.fromList(InputKeyMapUtils.getInputTypesForActionBinding(inputKeyMapList))
end

--- Converts keymap into ContextActionService friendly types
function InputKeyMapUtils.getInputTypesForActionBinding(inputKeyMapList)
	assert(type(inputKeyMapList) == "table", "inputKeyMapList must be a table")
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

function InputKeyMapUtils.getInputTypeListForMode(inputKeyMapList, inputMode)
	assert(type(inputKeyMapList) == "table", "inputKeyMapList must be a table")

	local results = {}
	local seen = {}

	for _, inputKeyMap in pairs(inputKeyMapList) do
		if inputKeyMap.inputMode == inputMode then
			for _, inputType in pairs(inputKeyMap.inputTypes) do
				if not seen then
					seen[inputType] = true
					table.insert(results, inputType)
				end
			end
		end
	end

	return results
end

function InputKeyMapUtils.getInputTypeSetForMode(inputKeyMapList, inputMode)
	assert(type(inputKeyMapList) == "table", "inputKeyMapList must be a table")

	local results = {}

	for _, inputKeyMap in pairs(inputKeyMapList) do
		if inputKeyMap.inputMode == inputMode then
			for _, inputType in pairs(inputKeyMap.inputTypes) do
				results[inputType] = true
			end
		end
	end

	return results
end


function InputKeyMapUtils.getInputModes(inputKeyMapList)
	assert(type(inputKeyMapList) == "table", "inputKeyMapList must be a table")

	local modes = {}
	for _, inputKeyMap in pairs(inputKeyMapList) do
		table.insert(modes, assert(inputKeyMap.inputMode))
	end

	return modes
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