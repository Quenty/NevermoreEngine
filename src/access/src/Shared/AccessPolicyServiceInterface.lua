--!strict
--[=[
	The tie for [AccessPolicyService], so a console pane or a debug UI can list policies and see what is
	running without depending on this package.

	Query only. Enabling a policy is not here on purpose: a policy is a consequence, and turning one on
	from anything that merely found an interface would make "something can see the registry" and
	"something can start kicking people" the same permission. Enabling stays on the service, behind the
	console's own admin gate.

	@class AccessPolicyServiceInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("AccessPolicyService", {
	GetPolicyNames = TieDefinition.Types.METHOD,
	ObservePolicyNames = TieDefinition.Types.METHOD,

	IsPolicyEnabled = TieDefinition.Types.METHOD,
	ObserveIsPolicyEnabled = TieDefinition.Types.METHOD,
	IsPolicyActiveForPlayer = TieDefinition.Types.METHOD,
	ObserveIsPolicyActiveForPlayer = TieDefinition.Types.METHOD,
	PromiseIsPolicyActiveForPlayer = TieDefinition.Types.METHOD,

	GetPolicyNamesReadingFact = TieDefinition.Types.METHOD,
	GetPolicyNamesReadingFeature = TieDefinition.Types.METHOD,

	GetDebugState = TieDefinition.Types.METHOD,
})
