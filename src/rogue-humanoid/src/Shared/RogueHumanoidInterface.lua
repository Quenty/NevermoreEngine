--!strict
--[=[
	@class RogueHumanoidInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("RogueHumanoid", {
	CreateMultiplier = TieDefinition.Types.METHOD,
	CreateAdditive = TieDefinition.Types.METHOD,
})
