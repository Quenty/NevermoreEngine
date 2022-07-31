--[=[
	@class PlayerInputModeTypes
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	GAMEPAD = "gamepad";
	TOUCH = "touch";
	KEYBOARD = "keyboard";
})