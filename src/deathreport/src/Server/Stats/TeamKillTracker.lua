--!strict
--[=[
	@class TeamKillTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DeathReportService = require("DeathReportService")
local DeathReportUtils = require("DeathReportUtils")
local ServiceBag = require("ServiceBag")

local TeamKillTracker = setmetatable({}, BaseObject)
TeamKillTracker.ClassName = "TeamKillTracker"
TeamKillTracker.__index = TeamKillTracker

export type TeamKillTracker =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_deathReportService: DeathReportService.DeathReportService,
			_team: Team,
		},
		{} :: typeof({ __index = TeamKillTracker })
	))
	& BaseObject.BaseObject

function TeamKillTracker.new(scoreObject: IntValue, serviceBag: ServiceBag.ServiceBag): TeamKillTracker
	local self: TeamKillTracker = setmetatable(BaseObject.new(scoreObject) :: any, TeamKillTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService) :: any

	-- Hm.... this is suppose to be generic, but this is not....
	self._maid:GiveTask(self._deathReportService.NewDeathReport:Connect(function(deathReport)
		self:_handleDeathReport(deathReport)
	end))

	local team = (self._obj :: IntValue).Parent
	assert(team and team:IsA("Team"), "Bad team")
	self._team = team

	return self
end

function TeamKillTracker.GetTeam(self: TeamKillTracker): Instance?
	return (self._obj :: IntValue).Parent
end

function TeamKillTracker.GetKills(self: TeamKillTracker): number
	return (self._obj :: IntValue).Value
end

function TeamKillTracker._handleDeathReport(self: TeamKillTracker, deathReport: DeathReportUtils.DeathReport)
	if deathReport.killerPlayer then
		if deathReport.killerPlayer.Team == self._team then
			-- increment kills
			local obj = self._obj :: IntValue
			obj.Value = obj.Value + 1
		end
	end
end

return TeamKillTracker
