--!strict
--[=[
	@class PlayerInputModeTypes
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

return SimpleEnum.new({
	GAMEPAD = "gamepad" :: "gamepad",
	TOUCH = "touch" :: "touch",
	KEYBOARD = "keyboard" :: "keyboard",
})
