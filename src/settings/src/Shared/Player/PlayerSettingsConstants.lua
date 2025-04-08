--!strict
--[=[
	@class PlayerSettingsConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	SETTING_ATTRIBUTE_PREFIX = "Setting_";
	SETTING_DEFAULT_VALUE_SUFFIX = "_Default";
	SETTING_LOCAL_USER_VALUE_SUFFIX = "_Client";

	PLAYER_SETTINGS_NAME = "PlayerSettings";
	REMOTE_FUNCTION_NAME = "PlayerSettingsRemoteFunction";
	REQUEST_UPDATE_SETTINGS = "requestUpdateSettings";
	MAX_SETTINGS_LENGTH = 2048;
})