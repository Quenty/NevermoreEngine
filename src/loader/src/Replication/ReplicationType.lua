--!strict
--[=[

	Different replication types we can be in.

	@class ReplicationType
]=]

local Utils = require(script.Parent.Parent.Utils)

export type ReplicationTypeMap = {
	CLIENT: "client",
	SERVER: "server",
	SHARED: "shared",
	PLUGIN: "plugin",
}

export type ReplicationType = "client" | "server" | "shared" | "plugin"

return Utils.readonly({
	CLIENT = "client",
	SERVER = "server",
	SHARED = "shared",
	PLUGIN = "plugin",
} :: ReplicationTypeMap)
