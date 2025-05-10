--!strict
--[=[
	Holds constants for resource retrieval.
	@class ResourceConstants
	@private
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	REMOTE_EVENT_STORAGE_NAME = "RemoteEvents" :: "RemoteEvents",
	REMOTE_FUNCTION_STORAGE_NAME = "RemoteFunctions" :: "RemoteFunctions",
})
