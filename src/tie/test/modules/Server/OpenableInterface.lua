--[[
	@class OpenableInterface
]]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("Openable", {
	Opening = TieDefinition.Types.SIGNAL,
	Closing = TieDefinition.Types.SIGNAL,
	IsOpen = TieDefinition.Types.PROPERTY,
	LastPromise = TieDefinition.Types.PROPERTY,
	PromiseOpen = TieDefinition.Types.METHOD,
	PromiseClose = TieDefinition.Types.METHOD,
})
