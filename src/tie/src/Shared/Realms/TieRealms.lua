--!strict
--[=[
	Realms sort of have to be a first class citizen...

	@class TieRealms
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type TieRealm = "shared" | "client" | "server"

return SimpleEnum.new({
	SHARED = "shared" :: "shared",
	CLIENT = "client" :: "client",
	SERVER = "server" :: "server",
})
