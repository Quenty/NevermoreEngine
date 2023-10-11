--[=[
	@class RacketingRopeConstraintInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("RacketingRopeConstraint", {
	PromiseConstrained = TieDefinition.Types.METHOD;
	ObserveIsConstrained = TieDefinition.Types.METHOD;
})