--[=[
	Test input key map provider
	@class TestInputKeyMap
]=]
local require = require(script.Parent.loader).load(script)

local INPUT_MODES = require("INPUT_MODES")
local InputKeyMap = require("InputKeyMap")
local InputKeyMapList = require("InputKeyMapList")
local InputKeyMapListProvider = require("InputKeyMapListProvider")
local SlottedTouchButtonUtils = require("SlottedTouchButtonUtils")

return InputKeyMapListProvider.new(script.Name, function(self)
	self:Add(InputKeyMapList.new("JUMP", {
		InputKeyMap.new(INPUT_MODES.KeyboardAndMouse, { Enum.KeyCode.Q });
		InputKeyMap.new(INPUT_MODES.Gamepads, { Enum.KeyCode.ButtonY });
		InputKeyMap.new(INPUT_MODES.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary3") });
	}))

	self:Add(InputKeyMapList.new("HONK", {
		InputKeyMap.new(INPUT_MODES.KeyboardAndMouse, { Enum.KeyCode.H });
		InputKeyMap.new(INPUT_MODES.Gamepads, { Enum.KeyCode.ButtonL1 });
		InputKeyMap.new(INPUT_MODES.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary2") });
	}))
end)