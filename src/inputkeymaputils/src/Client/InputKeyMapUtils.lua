--[=[
	Utility methods for input. Centralizes input. In the future, this will allow
	user configuration.

	```lua
	local inputMap = {
		JUMP = {
			InputKeyMapUtils.createKeyMap(INPUT_MODES.KeyboardAndMouse, { Enum.KeyCode.Space });
			InputKeyMapUtils.createKeyMap(INPUT_MODES.Gamepads, { Enum.KeyCode.ButtonA });
			InputKeyMapUtils.createKeyMap(INPUT_MODES.Touch, { InputKeyMapUtils.createSlottedTouchButton("primary3") });
		};
		HONK = {
			InputKeyMapUtils.createKeyMap(INPUT_MODES.KeyboardAndMouse, { Enum.KeyCode.H });
			InputKeyMapUtils.createKeyMap(INPUT_MODES.Gamepads, { Enum.KeyCode.DPadUp });
			InputKeyMapUtils.createKeyMap(INPUT_MODES.Touch, { InputKeyMapUtils.createSlottedTouchButton("primary2") });
		};
		BOOST = {
			InputKeyMapUtils.createKeyMap(INPUT_MODES.KeyboardAndMouse, { Enum.KeyCode.LeftControl });
			InputKeyMapUtils.createKeyMap(INPUT_MODES.Gamepads, { Enum.KeyCode.ButtonX });
			InputKeyMapUtils.createKeyMap(INPUT_MODES.Touch, { InputKeyMapUtils.createSlottedTouchButton("primary4") });
		};
	}
	```

	Then, we can use these input maps in a variety of services, including [ScoredActionService] or
	just binding directly to [ContextActionService].

	```lua
	local inputKeyMapList = inputMap.JUMP

	ContextActionService:BindActionAtPriority(
		"MyAction",
		function(_actionName, userInputState, inputObject)
			print("Process input", inputObject)
		end,
		InputKeyMapUtils.isRobloxTouchButton(inputKeyMapList),
		Enum.ContextActionPriority.High.Value,
		unpack(InputKeyMapUtils.getInputTypesForActionBinding(inputKeyMapList)))
	```

	@class InputKeyMapUtils
]=]

local require = require(script.Parent.loader).load(script)

local Set = require("Set")
local Table = require("Table")

local InputKeyMapUtils = {}

--[=[
	A valid input type that can be represented here.
	@type InputType KeyCode | UserInputType | SlottedTouchButton | "TouchButton" | "Tap" | any
	@within InputKeyMapUtils
]=]

--[=[
	A grouping of input types for a specific input mode to use.

	@interface InputKeyMap
	.inputMode InputMode
	.inputTypes { InputType }
	@within InputKeyMapUtils
]=]

--[=[
	A mapping of input keys to maps
	@type InputKeyMapList { InputKeyMap }
	@within InputKeyMapUtils
]=]

--[=[
	Should be called "createInputKeyMap". Creates a new InputKeyMap.

	@param inputMode InputMode
	@param inputTypes { InputType }
	@return InputKeyMap
]=]
function InputKeyMapUtils.createKeyMap(inputMode, inputTypes)
	assert(type(inputMode) == "table", "Bad inputMode")
	assert(type(inputTypes) == "table", "Bad inputTypes")

	return Table.readonly({
		inputMode = inputMode;
		inputTypes = inputTypes;
	})
end

--[=[
	@param inputKeyMapList InputKeyMapList
	@return { KeyCode | UserInputType }
]=]
function InputKeyMapUtils.getInputTypesSetForActionBinding(inputKeyMapList)
	return Set.fromList(InputKeyMapUtils.getInputTypesForActionBinding(inputKeyMapList))
end

--[=[
	Converts keymap into ContextActionService friendly types
	@param inputKeyMapList InputKeyMapList
	@return { KeyCode | UserInputType }
]=]
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

--[=[
	Given an inputMode, gets the relevant lists available
	@param inputKeyMapList InputKeyMapList
	@param inputMode InputMode
	@return { InputKeyMap }
]=]
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

--[=[
	Gets a set of input types for a given mode from the list.

	@param inputKeyMapList InputKeyMapList
	@param inputMode InputMode
	@return { [InputType] = true }
]=]
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

--[=[
	Retrieves the set of input modes for a given list.

	@param inputKeyMapList InputKeyMapList
	@return { InputMode }
]=]
function InputKeyMapUtils.getInputModes(inputKeyMapList)
	assert(type(inputKeyMapList) == "table", "inputKeyMapList must be a table")

	local modes = {}
	for _, inputKeyMap in pairs(inputKeyMapList) do
		local mode = assert(inputKeyMap.inputMode, "Bad inputKeyMap.inputMode")
		table.insert(modes, mode)
	end

	return modes
end

--[=[
	Internal data representing a slotted touch button
	@interface SlottedTouchButtonData
	.slotId string
	.inputMode InputMode
	@within InputKeyMapUtils
]=]

--[=[
	Gets slotted touch button data for an inputKeyMapList

	@param inputKeyMapList InputKeyMapList
	@return { SlottedTouchButtonData }
]=]
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

--[=[
	Returns whether an inputType is a SlottedTouchButton type

	@param inputType any
	@return boolean
]=]
function InputKeyMapUtils.isSlottedTouchButton(inputType)
	return type(inputType) == "table" and inputType.type == "SlottedTouchButton"
end

--[=[
	A touch button that goes into a specific slot. This ensures
	consistent slot positions.

	@interface SlottedTouchButton
	.type "SlottedTouchButton"
	.slotId string
	@within InputKeyMapUtils
]=]

--[=[
	Touch buttons should always show up in the same position
	We use the SlotId to determine which slot we should put
	these buttons in.

	@param slotId string
	@return SlottedTouchButton
]=]
function InputKeyMapUtils.createSlottedTouchButton(slotId)
	assert(slotId == "primary1"
		or slotId == "primary2"
		or slotId == "primary3"
		or slotId == "primary4"
		or slotId == "touchpad1", "Bad slotId")

	return {
		type = "SlottedTouchButton";
		slotId = slotId;
	}
end

--[=[
	Computes a unique id for an inputType which can be used
	in a set to deduplicate/compare the objects. Used to know
	when to exclude different types from each other.

	@param inputType InputType
	@return any
]=]
function InputKeyMapUtils.getUniqueKeyForInputType(inputType)
	if InputKeyMapUtils.isSlottedTouchButton(inputType) then
		return inputType.slotId
	else
		return inputType
	end
end

--[=[
	Only returns true if we're a Roblox touch button
	@param inputKeyMapList InputKeyMapList
	@return boolean
]=]
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

--[=[
	Whether this input type is a tap in the world input (for touched events)
	@param inputKeyMapList InputKeyMapList
	@return boolean
]=]
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