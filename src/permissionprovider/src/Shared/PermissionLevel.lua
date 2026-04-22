--!strict
--[=[
	@class PermissionLevel
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type PermissionLevel = "admin" | "creator"

return SimpleEnum.new({
	ADMIN = "admin" :: "admin",
	CREATOR = "creator" :: "creator",
})
