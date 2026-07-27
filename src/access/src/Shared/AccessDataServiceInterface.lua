--!strict
--[=[
	The tie for [AccessDataService], so other packages can ask about access without depending on this one.

	A package like an area-gating library should not have to `require` the access package -- and should
	not break in a game that has no access package at all. It reaches the implementation through this
	definition instead, and simply finds nothing when access is not installed.

	```lua
	local accessDataService = AccessDataServiceInterface:Find(ReplicatedStorage)
	if accessDataService then
		accessDataService:ObserveIsFeatureAllowedByName(player, "chapters"):Subscribe(...)
	end
	```

	## Why the members are name-based

	A consumer that already holds an [AccessFeature] object also holds this package, so it does not need a
	tie. The methods worth exposing here are the ones addressable by **string**, which is what a decoupled
	consumer actually has -- the same names the console autocompletes.

	## Why overriding is server-only here

	Setting a fact is granting an entitlement. Putting the setters behind
	[TieDefinition.Realms].SERVER means a client-side consumer cannot even see them, so the rule is
	enforced by the interface rather than by a comment asking people to behave.

	@class AccessDataServiceInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("AccessDataService", {
	GetFactNames = TieDefinition.Types.METHOD,
	GetFeatureNames = TieDefinition.Types.METHOD,
	HasFact = TieDefinition.Types.METHOD,
	HasFeature = TieDefinition.Types.METHOD,

	IsFeatureAllowedByName = TieDefinition.Types.METHOD,
	ObserveIsFeatureAllowedByName = TieDefinition.Types.METHOD,
	PromiseIsFeatureAllowedByName = TieDefinition.Types.METHOD,
	ObserveFeatureAllowedStateByName = TieDefinition.Types.METHOD,

	ObserveFactReport = TieDefinition.Types.METHOD,
	ObserveFactReports = TieDefinition.Types.METHOD,

	ObserveIsPlayerPresent = TieDefinition.Types.METHOD,

	[TieDefinition.Realms.SERVER] = {
		SetFactOverride = TieDefinition.Types.METHOD,
		ClearFactOverride = TieDefinition.Types.METHOD,
		ClearFactOverrides = TieDefinition.Types.METHOD,
		TeardownPlayer = TieDefinition.Types.METHOD,
	},
})
