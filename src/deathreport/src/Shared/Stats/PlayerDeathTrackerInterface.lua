--!strict
--[=[
	Tie interface implemented by [PlayerDeathTracker] and [PlayerDeathTrackerClient] on the tracked
	[IntValue], so consumers can read a player's deaths without depending on either binder.

	@class PlayerDeathTrackerInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("PlayerDeathTracker", {
	GetPlayer = TieDefinition.Types.METHOD,
	GetDeathValue = TieDefinition.Types.METHOD,
	GetDeaths = TieDefinition.Types.METHOD,
	ObserveDeaths = TieDefinition.Types.METHOD,
})
