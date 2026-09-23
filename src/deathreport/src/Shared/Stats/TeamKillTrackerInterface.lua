--!strict
--[=[
	Tie interface implemented by [TeamKillTracker] and [TeamKillTrackerClient] on the tracked
	[IntValue], so consumers can read a team's kills without depending on either binder.

	@class TeamKillTrackerInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("TeamKillTracker", {
	GetTeam = TieDefinition.Types.METHOD,
	GetKillValue = TieDefinition.Types.METHOD,
	GetKills = TieDefinition.Types.METHOD,
	ObserveKills = TieDefinition.Types.METHOD,
})
