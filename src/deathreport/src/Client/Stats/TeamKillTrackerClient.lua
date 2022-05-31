--[=[
	@class TeamKillTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")

local TeamKillTrackerClient = setmetatable({}, BaseObject)
TeamKillTrackerClient.ClassName = "TeamKillTrackerClient"
TeamKillTrackerClient.__index = TeamKillTrackerClient

function TeamKillTrackerClient.new(tracker)
	local self = setmetatable(BaseObject.new(tracker), TeamKillTrackerClient)

	self.KillsChanged = self._obj.Changed

	return self
end

function TeamKillTrackerClient:GetKillValue()
	return self._obj
end

function TeamKillTrackerClient:GetTeam()
	return self._obj.Parent
end

function TeamKillTrackerClient:GetKills()
	return self._obj.Value
end

return TeamKillTrackerClient