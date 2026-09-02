--!strict
--[=[
	@class PlayerMockConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	MOCK_TAG = "PlayerMock",
	LOCAL_PLAYER_TAG = "PlayerMockLocalPlayer",

	PROPERTY_OBJECT_NAME_PREFIX = "PlayerMockProperty_",
	SIGNAL_NAME_PREFIX = "PlayerMockSignal_",
	METHOD_BINDING_NAME_PREFIX = "PlayerMockMethod_",
	ACTION_NAME_PREFIX = "PlayerMockAction_",
	CORE_EVENT_NAME_PREFIX = "PlayerMockCore_",

	PLAYER_GUI_NAME = "PlayerGui",
	PLAYER_SCRIPTS_NAME = "PlayerScripts",

	KICK_MESSAGE_ATTRIBUTE = "PlayerMockKickMessage",
	REPLICATION_FOCUS_FOLDER_NAME = "PlayerMockReplicationFocuses",
})
