--[=[
	@class TemplateReplicationModes
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	CLIENT = "client";
	SERVER = "server";
	SHARED = "shared";
})