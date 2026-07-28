--!strict
--[=[
	The tie for [AccessPlayerBase], so anything holding a player can ask about their access without
	requiring the access package or plumbing a [ServiceBag] to the call site.

	```lua
	local accessPlayer = AccessPlayerInterface:Find(player)
	if accessPlayer and not accessPlayer:IsFeatureAllowedByName("owns-game") then
		return
	end
	```

	Members are name-based for the same reason [AccessDataServiceInterface]'s are: a consumer that already
	holds an [AccessFeature] object also holds this package. The setters sit behind
	[TieDefinition.Realms].SERVER, so a client cannot see them at all.

	@class AccessPlayerInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("AccessPlayer", {
	IsFeatureAllowedByName = TieDefinition.Types.METHOD,
	ObserveIsFeatureAllowedByName = TieDefinition.Types.METHOD,
	PromiseIsFeatureAllowedByName = TieDefinition.Types.METHOD,
	GetFeatureAllowedStateByName = TieDefinition.Types.METHOD,
	ObserveFeatureAllowedStateByName = TieDefinition.Types.METHOD,

	GetFactMetadata = TieDefinition.Types.METHOD,
	ObserveFactMetadata = TieDefinition.Types.METHOD,

	GetDebugState = TieDefinition.Types.METHOD,

	FeatureAllowedChanged = TieDefinition.Types.SIGNAL,

	[TieDefinition.Realms.SERVER] = {
		SetFactOverride = TieDefinition.Types.METHOD,
		ClearFactOverride = TieDefinition.Types.METHOD,
		ClearFactOverrides = TieDefinition.Types.METHOD,
	},
})
