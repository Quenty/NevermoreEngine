--[=[
	@class SoftShutdownConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	IS_SOFT_SHUTDOWN_LOBBY_ATTRIBUTE = "IsSoftShutdownLobby";
	IS_SOFT_SHUTDOWN_UPDATING_ATTRIBUTE = "IsSoftshutdownRebootingServers";
})