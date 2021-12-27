--[=[
	Utility functions to configure a proximity prompt based upon the
	input key map given.
	@class ProximityPromptInputUtils
]=]

local require = require(script.Parent.loader).load(script)

local InputKeyMapUtils = require("InputKeyMapUtils")
local INPUT_MODES = require("INPUT_MODES")

local ProximityPromptInputUtils = {}

--[=[
	Creates an InputKeyMapList from a proximity prompt.

	@param prompt ProximityPrompt
	@return InputKeyMapList
]=]
function ProximityPromptInputUtils.inputKeyMapFromPrompt(prompt)
	assert(typeof(prompt) == "Instance", "Bad prompt")

	return {
		InputKeyMapUtils.createKeyMap(INPUT_MODES.Gamepads, { prompt.GamepadKeyCode });
		InputKeyMapUtils.createKeyMap(INPUT_MODES.Keyboard, { prompt.KeyboardKeyCode })
	}
end


--[=[
	Sets the key codes for a proximity prompt to match an inputKeyMapList

	@param prompt ProximityPrompt
	@param inputKeyMapList InputKeyMapList
]=]
function ProximityPromptInputUtils.configurePromptFromInputKeyMap(prompt, inputKeyMapList)
	assert(typeof(prompt) == "Instance", "Bad prompt")
	assert(type(inputKeyMapList) == "table", "Bad inputKeyMapList")

	local keyboard = ProximityPromptInputUtils.getFirstInputKeyCode(inputKeyMapList, INPUT_MODES.Keyboard)
	local gamepad = ProximityPromptInputUtils.getFirstInputKeyCode(inputKeyMapList, INPUT_MODES.Gamepads)

	if keyboard then
		prompt.KeyboardKeyCode = keyboard
	end

	if gamepad then
		prompt.GamepadKeyCode = gamepad
	end
end

--[=[
	Picks the first keyCode that matches the inputMode.

	@param inputKeyMapList InputKeyMapList
	@param inputMode InputMode
	@return KeyCode?
]=]
function ProximityPromptInputUtils.getFirstInputKeyCode(inputKeyMapList, inputMode)
	assert(type(inputKeyMapList) == "table", "Bad inputKeyMapList")
	assert(inputMode, "Bad inputMode")

	for _, item in pairs(inputKeyMapList) do
		for _, entry in pairs(item.inputTypes) do
			if typeof(entry) == "EnumItem"
				and entry.EnumType == Enum.KeyCode
				and inputMode:IsValid(entry) then

				return entry
			end
		end
	end

	return nil
end

return ProximityPromptInputUtils