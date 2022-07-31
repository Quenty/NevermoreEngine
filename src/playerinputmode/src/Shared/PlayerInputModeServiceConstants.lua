--[=[
	@class PlayerInputModeServiceConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	REMOTE_EVENT_NAME = "PlayerInputModeRemoteEvent";
	INPUT_MODE_ATTRIBUTE = "PlayerInputMode";
	REQUEST_SET_INPUT_MODE = "requestSetInputMode";
})