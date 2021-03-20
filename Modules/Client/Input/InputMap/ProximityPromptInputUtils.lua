---
-- @module ProximityPromptInputUtils
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local InputKeyMapUtils = require("InputKeyMapUtils")
local INPUT_MODES = require("INPUT_MODES")

local ProximityPromptInputUtils = {}

function ProximityPromptInputUtils.inputKeyMapFromPrompt(prompt)
	return {
		InputKeyMapUtils.createKeyMap(INPUT_MODES.Gamepads, { prompt.GamepadKeyCode });
		InputKeyMapUtils.createKeyMap(INPUT_MODES.Keyboard, { prompt.KeyboardKeyCode })
	}
end

function ProximityPromptInputUtils.configurePromptFromInputKeyMap(prompt, inputKeyMapList)
	local keyboard = ProximityPromptInputUtils.getFirstInputKeyCode(prompt, inputKeyMapList, INPUT_MODES.Keyboard)
	local gamepad = ProximityPromptInputUtils.getFirstInputKeyCode(prompt, inputKeyMapList, INPUT_MODES.Gamepads)

	if keyboard then
		prompt.KeyboardKeyCode = keyboard
	end

	if gamepad then
		prompt.GamepadKeyCode = gamepad
	end
end

function ProximityPromptInputUtils.getFirstInputKeyCode(prompt, inputKeyMapList, inputMode)
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