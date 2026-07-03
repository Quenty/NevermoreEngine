--!strict
--[=[
	@class RemotingRealms
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type RemotingRealm = "server" | "client"

return SimpleEnum.new({
	SERVER = "server" :: "server",
	CLIENT = "client" :: "client",
})
