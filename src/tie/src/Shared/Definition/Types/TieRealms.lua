--[=[
	Realms sort of have to be a first class citizen...

	@class TieRealms
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")
local Symbol = require("Symbol")

return Table.readonly({
	SHARED = Symbol.named("shared");
	CLIENT = Symbol.named("client");
	SERVER = Symbol.named("server");
})