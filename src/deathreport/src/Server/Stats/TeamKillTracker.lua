--!strict
--[=[
	Counts the kills scored by one team. Bound to an [IntValue] parented under a [Team]; every death
	report whose killer is on that team increments the value.

	Retrieve the binder from a [ServiceBag] with `serviceBag:GetService(require("TeamKillTracker"))`
	and create tracked values with [TeamKillTrackerUtils.create].

	@server
	@class TeamKillTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local DeathReportService = require("DeathReportService")
local DeathReportUtils = require("DeathReportUtils")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local RxValueBaseUtils = require("RxValueBaseUtils")
local ServiceBag = require("ServiceBag")
local TeamKillTrackerInterface = require("TeamKillTrackerInterface")

local TeamKillTracker = setmetatable({}, BaseObject)
TeamKillTracker.ClassName = "TeamKillTracker"
TeamKillTracker.__index = TeamKillTracker

export type TeamKillTracker =
	typeof(setmetatable(
		{} :: {
			_obj: IntValue,
			_serviceBag: ServiceBag.ServiceBag,
			_deathReportService: DeathReportService.DeathReportService,
			_team: Team,
		},
		{} :: typeof({ __index = TeamKillTracker })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new TeamKillTracker. Should be done via the binder.

	@param scoreObject IntValue -- Parented under the [Team] to track
	@param serviceBag ServiceBag
	@return TeamKillTracker
]=]
function TeamKillTracker.new(scoreObject: IntValue, serviceBag: ServiceBag.ServiceBag): TeamKillTracker
	local self: TeamKillTracker = setmetatable(BaseObject.new(scoreObject) :: any, TeamKillTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService) :: any

	local team = self._obj.Parent
	assert(team and team:IsA("Team"), "Bad team")
	self._team = team

	self._maid:GiveTask(self._deathReportService.NewDeathReport:Connect(function(deathReport)
		self:_handleDeathReport(deathReport)
	end))

	self._maid:GiveTask(TeamKillTrackerInterface.Server:Implement(self._obj, self))

	return self
end

--[=[
	Returns the team whose kills are tracked
	@return Instance?
]=]
function TeamKillTracker.GetTeam(self: TeamKillTracker): Instance?
	return self._obj.Parent
end

--[=[
	Returns the value holding the kill count
	@return IntValue
]=]
function TeamKillTracker.GetKillValue(self: TeamKillTracker): IntValue
	return self._obj
end

--[=[
	Returns the number of kills scored by the team
	@return number
]=]
function TeamKillTracker.GetKills(self: TeamKillTracker): number
	return self._obj.Value
end

--[=[
	Observes the number of kills scored by the team
]=]
function TeamKillTracker.ObserveKills(self: TeamKillTracker): Observable.Observable<number>
	return RxValueBaseUtils.observeValue(self._obj)
end

function TeamKillTracker._handleDeathReport(self: TeamKillTracker, deathReport: DeathReportUtils.DeathReport)
	local killerPlayer = deathReport.killerPlayer
	if not killerPlayer then
		return
	end

	local killerTeam = if PlayerMock.isMock(killerPlayer)
		then PlayerMock.read(killerPlayer, "Team")
		else killerPlayer.Team
	if killerTeam == self._team then
		self._obj.Value = self._obj.Value + 1
	end
end

return Binder.new("TeamKillTracker", TeamKillTracker :: any) :: Binder.Binder<TeamKillTracker>
