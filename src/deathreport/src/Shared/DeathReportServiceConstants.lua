--!strict
--[=[
	@class DeathReportServiceConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	REMOTING_NAME = "DeathReportService",
	DEATH_REPORTED_EVENT_NAME = "DeathReported",

	-- Replicated IntValues a [PlayerKillTracker] and [PlayerDeathTracker] keep under the player
	PLAYER_KILL_VALUE_NAME = "PlayerKillTracker",
	PLAYER_DEATH_VALUE_NAME = "PlayerDeathTracker",
})
