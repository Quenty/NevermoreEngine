--[=[
	Utility functions to configure a proximity prompt based upon the
	input key map given.
	@class ProximityPromptInputUtils
]=]

local require = require(script.Parent.loader).load(script)

local InputKeyMapList = require("InputKeyMapList")
local InputModeTypes = require("InputModeTypes")
local InputKeyMap = require("InputKeyMap")
local InputModeType = require("InputModeType")

local ProximityPromptInputUtils = {}

--[=[
	Creates an InputKeyMapList from a proximity prompt.

	@param prompt ProximityPrompt
	@return InputKeyMapList
]=]
function ProximityPromptInputUtils.newInputKeyMapFromPrompt(prompt)
	assert(typeof(prompt) == "Instance", "Bad prompt")

	return InputKeyMapList.new("custom", {
		InputKeyMap.new(InputModeTypes.Gamepads, { prompt.GamepadKeyCode });
		InputKeyMap.new(InputModeTypes.KeyboardAndMouse, { prompt.KeyboardKeyCode });
		InputKeyMap.new(InputModeTypes.Touch, { "Tap" });
	}, {
		bindingName = prompt.ActionText;
		rebindable = false;
	})
end


--[=[
	Sets the key codes for a proximity prompt to match an inputKeyMapList

	@param prompt ProximityPrompt
	@param inputKeyMapList InputKeyMapList
]=]
function ProximityPromptInputUtils.configurePromptFromInputKeyMap(prompt, inputKeyMapList)
	assert(typeof(prompt) == "Instance", "Bad prompt")
	assert(type(inputKeyMapList) == "table", "Bad inputKeyMapList")

	local keyboard = ProximityPromptInputUtils.getFirstInputKeyCode(inputKeyMapList, InputModeTypes.KeyboardAndMouse)
	local gamepad = ProximityPromptInputUtils.getFirstInputKeyCode(inputKeyMapList, InputModeTypes.Gamepads)

	if keyboard then
		prompt.KeyboardKeyCode = keyboard
	end

	if gamepad then
		prompt.GamepadKeyCode = gamepad
	end
end

--[=[
	Picks the first keyCode that matches the inputModeType.

	@param inputKeyMapList InputKeyMapList
	@param inputModeType InputModeType
	@return KeyCode?
]=]
function ProximityPromptInputUtils.getFirstInputKeyCode(inputKeyMapList, inputModeType)
	assert(type(inputKeyMapList) == "table", "Bad inputKeyMapList")
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")

	for _, item in pairs(inputKeyMapList) do
		for _, entry in pairs(item.inputTypes) do
			if typeof(entry) == "EnumItem"
				and entry.EnumType == Enum.KeyCode
				and inputModeType:IsValid(entry) then

				return entry
			end
		end
	end

	return nil
end

return ProximityPromptInputUtils