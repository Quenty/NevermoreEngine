--[=[
	@class RagdollableInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("Ragdollable", {
	Ragdolled = TieDefinition.Types.SIGNAL,
	Unragdolled = TieDefinition.Types.SIGNAL,

	Ragdoll = TieDefinition.Types.METHOD,
	Unragdoll = TieDefinition.Types.METHOD,
	ObserveIsRagdolled = TieDefinition.Types.METHOD,
	IsRagdolled = TieDefinition.Types.METHOD,
})
