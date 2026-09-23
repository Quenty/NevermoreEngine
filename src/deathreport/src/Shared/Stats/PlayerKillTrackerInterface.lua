--!strict
--[=[
	Tie interface implemented by [PlayerKillTracker] and [PlayerKillTrackerClient] on the tracked
	[IntValue], so consumers can read a player's kills without depending on either binder.

	@class PlayerKillTrackerInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("PlayerKillTracker", {
	GetPlayer = TieDefinition.Types.METHOD,
	GetKillValue = TieDefinition.Types.METHOD,
	GetKills = TieDefinition.Types.METHOD,
	ObserveKills = TieDefinition.Types.METHOD,
})
