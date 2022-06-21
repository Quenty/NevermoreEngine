--[=[
	@class TeamKillTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DeathReportService = require("DeathReportService")

local TeamKillTracker = setmetatable({}, BaseObject)
TeamKillTracker.ClassName = "TeamKillTracker"
TeamKillTracker.__index = TeamKillTracker

function TeamKillTracker.new(scoreObject, serviceBag)
	local self = setmetatable(BaseObject.new(scoreObject), TeamKillTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService)

	-- Hm.... this is suppose to be generic, but this is not....
	self._maid:GiveTask(self._deathReportService.NewDeathReport:Connect(function(deathReport)
		self:_handleDeathReport(deathReport)
	end))

	self._team = self._obj.Parent
	assert(self._team and self._team:IsA("Team"), "Bad team")

	return self
end

function TeamKillTracker:GetTeam()
	return self._obj.Parent
end

function TeamKillTracker:GetKills()
	return self._obj.Value
end

function TeamKillTracker:_handleDeathReport(deathReport)
	if deathReport.killerPlayer then
		if deathReport.killerPlayer.Team == self._team then
			-- increment kills
			self._obj.Value = self._obj.Value + 1
		end
	end
end

return TeamKillTracker