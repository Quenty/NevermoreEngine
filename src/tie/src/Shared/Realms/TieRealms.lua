--!strict
--[=[
	Realms sort of have to be a first class citizen...

	@class TieRealms
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

export type TieRealm = "shared" | "client" | "server"

export type TieRealms = {
	SHARED: "shared",
	CLIENT: "client",
	SERVER: "server",
}

return Table.readonly({
	SHARED = "shared",
	CLIENT = "client",
	SERVER = "server",
} :: TieRealms)
