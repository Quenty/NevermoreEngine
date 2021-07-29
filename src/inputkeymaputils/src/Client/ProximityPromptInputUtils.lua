---
-- @module ProximityPromptInputUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local InputKeyMapUtils = require("InputKeyMapUtils")
local INPUT_MODES = require("INPUT_MODES")

local ProximityPromptInputUtils = {}

function ProximityPromptInputUtils.inputKeyMapFromPrompt(prompt)
	assert(typeof(prompt) == "Instance", "Bad prompt")

	return {
		InputKeyMapUtils.createKeyMap(INPUT_MODES.Gamepads, { prompt.GamepadKeyCode });
		InputKeyMapUtils.createKeyMap(INPUT_MODES.Keyboard, { prompt.KeyboardKeyCode })
	}
end

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