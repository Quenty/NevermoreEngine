--!strict
--[=[
	@class TeamKillTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")

local TeamKillTrackerClient = setmetatable({}, BaseObject)
TeamKillTrackerClient.ClassName = "TeamKillTrackerClient"
TeamKillTrackerClient.__index = TeamKillTrackerClient

export type TeamKillTrackerClient =
	typeof(setmetatable(
		{} :: {
			KillsChanged: RBXScriptSignal,
		},
		{} :: typeof({ __index = TeamKillTrackerClient })
	))
	& BaseObject.BaseObject

function TeamKillTrackerClient.new(tracker: IntValue): TeamKillTrackerClient
	local self: TeamKillTrackerClient = setmetatable(BaseObject.new(tracker) :: any, TeamKillTrackerClient)

	self.KillsChanged = self:GetKillValue().Changed

	return self
end

function TeamKillTrackerClient.GetKillValue(self: TeamKillTrackerClient): IntValue
	return self._obj :: IntValue
end

function TeamKillTrackerClient.GetTeam(self: TeamKillTrackerClient): Instance?
	return self:GetKillValue().Parent
end

function TeamKillTrackerClient.GetKills(self: TeamKillTrackerClient): number
	return self:GetKillValue().Value
end

return TeamKillTrackerClient
