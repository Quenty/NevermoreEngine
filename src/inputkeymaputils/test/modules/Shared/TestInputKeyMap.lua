--[=[
	Test input key map provider
	@class TestInputKeyMap
]=]
local require = require(script.Parent.loader).load(script)

local InputModeTypes = require("InputModeTypes")
local InputKeyMap = require("InputKeyMap")
local InputKeyMapList = require("InputKeyMapList")
local InputKeyMapListProvider = require("InputKeyMapListProvider")
local SlottedTouchButtonUtils = require("SlottedTouchButtonUtils")

return InputKeyMapListProvider.new(script.Name, function(self)
	self:Add(InputKeyMapList.new("JUMP", {
		InputKeyMap.new(InputModeTypes.KeyboardAndMouse, { Enum.KeyCode.Q });
		InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.ButtonY });
		InputKeyMap.new(InputModeTypes.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary3") });
	}, {
		bindingName = "Jump";
		rebindable = true;
	}))

	self:Add(InputKeyMapList.new("HONK", {
		InputKeyMap.new(InputModeTypes.KeyboardAndMouse, { Enum.KeyCode.H });
		InputKeyMap.new(InputModeTypes.Gamepads, { Enum.KeyCode.ButtonL1 });
		InputKeyMap.new(InputModeTypes.Touch, { SlottedTouchButtonUtils.createSlottedTouchButton("primary2") });
	}, {
		bindingName = "Honk";
		rebindable = true;
	}))
end)