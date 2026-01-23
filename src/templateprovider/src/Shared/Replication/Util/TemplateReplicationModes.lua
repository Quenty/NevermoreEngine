--!strict
--[=[
	@class TemplateReplicationModes
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type TemplateReplicationMode = "client" | "server" | "shared"

return SimpleEnum.new({
	CLIENT = "client" :: "client",
	SERVER = "server" :: "server",
	SHARED = "shared" :: "shared",
})
