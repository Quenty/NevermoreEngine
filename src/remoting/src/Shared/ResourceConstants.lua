--- Holds constants for resource retrieval
-- @module ResourceConstants

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	REMOTE_EVENT_STORAGE_NAME = "RemoteEvents";
	REMOTE_FUNCTION_STORAGE_NAME = "RemoteFunctions";
})