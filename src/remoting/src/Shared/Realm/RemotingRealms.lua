--!strict
--[=[
	@class RemotingRealms
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

export type RemotingRealm = "server" | "client"

export type RemotingRealms = {
	SERVER: "server",
	CLIENT: "client",
}

return Table.readonly({
	SERVER = "server",
	CLIENT = "client",
} :: RemotingRealms)
