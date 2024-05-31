--[=[
	Realms sort of have to be a first class citizen...

	@class TieRealms
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	SHARED = "shared";
	CLIENT = "client";
	SERVER = "server";
})