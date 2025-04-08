--!strict
--[=[
	@class PermissionLevel
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

export type PermissionLevel = "admin" | "creator"

export type PermissionLevelMap = {
	ADMIN: "admin",
	CREATOR: "creator",
}

return Table.readonly({
	ADMIN = "admin",
	CREATOR = "creator",
} :: PermissionLevelMap)
