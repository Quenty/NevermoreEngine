--!strict
--[=[
	@class TemplateReplicationModes
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

export type TemplateReplicationMode = "client" | "server" | "shared"

type TemplateReplicationModeMap = {
	CLIENT: "client",
	SERVER: "server",
	SHARED: "shared",
}

return Table.readonly({
	CLIENT = "client",
	SERVER = "server",
	SHARED = "shared",
} :: TemplateReplicationModeMap)
