--- Utility methods for input map
-- @module InputKeyMapUtils
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Set = require("Set")
local Table = require("Table")

local InputKeyMapUtils = {}

-- Should be called "createInputKeyMapList"
function InputKeyMapUtils.createKeyMap(inputMode, inputTypes)
	assert(type(inputMode) == "table", "Bad inputMode")
	assert(type(inputTypes) == "table", "Bad inputTypes")

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
		assert(inputKeyMap.inputMode, "Bad inputKeyMap.inputMode")
		assert(inputKeyMap.inputTypes, "Bad inputKeyMap.inputTypes")

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
		local mode = assert(inputKeyMap.inputMode, "Bad inputKeyMap.inputMode")
		table.insert(modes, mode)
	end

	return modes
end

function InputKeyMapUtils.getSlottedTouchButtonData(inputKeyMapList)
	local slottedTouchButtons = {}

	for _, inputKeyMap in pairs(inputKeyMapList) do
		assert(inputKeyMap.inputMode, "Bad inputKeyMap.inputMode")
		assert(inputKeyMap.inputTypes, "Bad inputKeyMap.inputTypes")

		for _, touchButtonData in pairs(inputKeyMap.inputTypes) do
			if InputKeyMapUtils.isSlottedTouchButton(touchButtonData) then
				table.insert(slottedTouchButtons, {
					slotId = touchButtonData.slotId;
					inputMode = inputKeyMap.inputMode;
				})
			end
		end
	end

	return slottedTouchButtons
end

function InputKeyMapUtils.isSlottedTouchButton(inputType)
	return type(inputType) == "table" and inputType.type == "SlottedTouchButton"
end

-- Touch buttons should always show up in the same position
-- We use the SlotId to determine which slot we should put these buttons in
function InputKeyMapUtils.createSlottedTouchButton(slotId)
	assert(slotId == "primary1" or slotId == "primary2" or slotId == "primary3" or slotId == "primary4", "Bad slotId")

	return {
		type = "SlottedTouchButton";
		slotId = slotId;
	}
end

function InputKeyMapUtils.getUniqueKeyForInputType(inputType)
	if InputKeyMapUtils.isSlottedTouchButton(inputType) then
		return inputType.slotId
	else
		return inputType
	end
end

-- Only returns true if we're a Roblox touch button
function InputKeyMapUtils.isRobloxTouchButton(inputKeyMapList)
	for _, inputKeyMap in pairs(inputKeyMapList) do
		assert(inputKeyMap.inputMode, "Bad inputKeyMap.inputMode")
		assert(inputKeyMap.inputTypes, "Bad inputKeyMap.inputTypes")

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
		assert(inputKeyMap.inputMode, "Bad inputKeyMap.inputMode")
		assert(inputKeyMap.inputTypes, "Bad inputKeyMap.inputTypes")

		for _, _type in pairs(inputKeyMap.inputTypes) do
			if _type == "Tap" then
				return true
			end
		end
	end

	return false
end

return InputKeyMapUtils