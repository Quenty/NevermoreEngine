--[=[
	@class RemotingRealms
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	SERVER = "server";
	CLIENT = "client";
})