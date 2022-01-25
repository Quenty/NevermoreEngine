--[=[
	@class GameConfigServiceConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	REMOTE_FUNCTION_NAME = "GameConfigServiceRemoteFunction";
	REMOTE_EVENT_NAME = "GameConfigServiceRemoteEvent";
	REQUEST_CONFIGURATION_DATA = "requestConfigurationData";
	REQUEST_ADD_CONFIG = "requestAddConfig";
})