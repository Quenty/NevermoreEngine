--[[
	@class ActionInterface
]]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("Action", {
	DisplayName = "???",
	IsEnabled = false,
	Activated = TieDefinition.Types.SIGNAL,
	Activate = TieDefinition.Types.METHOD,
})
