--- Holds constants for resource retrieval
-- @module ResourceConstants

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Table = require("Table")

return Table.ReadOnly({
	REMOTE_EVENT_STORAGE_NAME = "RemoteEvents";
	REMOTE_FUNCTION_STORAGE_NAME = "RemoteFunctions";
})