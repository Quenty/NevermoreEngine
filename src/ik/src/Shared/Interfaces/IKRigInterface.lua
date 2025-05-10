--[=[
	@class IKRigInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("IKRig", {
	GetPlayer = TieDefinition.Types.METHOD,
	GetHumanoid = TieDefinition.Types.METHOD,

	PromiseLeftArm = TieDefinition.Types.METHOD,
	PromiseRightArm = TieDefinition.Types.METHOD,
	GetLeftArm = TieDefinition.Types.METHOD,
	GetRightArm = TieDefinition.Types.METHOD,

	GetAimPosition = TieDefinition.Types.METHOD,
})
