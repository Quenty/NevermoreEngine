--!strict
--[=[
	Client view of a [TeamKillTracker]: reads the replicated kill count of a team.

	Retrieve the binder from a [ServiceBag] with `serviceBag:GetService(require("TeamKillTrackerClient"))`.

	@client
	@class TeamKillTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local Observable = require("Observable")
local RxValueBaseUtils = require("RxValueBaseUtils")
local TeamKillTrackerInterface = require("TeamKillTrackerInterface")

local TeamKillTrackerClient = setmetatable({}, BaseObject)
TeamKillTrackerClient.ClassName = "TeamKillTrackerClient"
TeamKillTrackerClient.__index = TeamKillTrackerClient

export type TeamKillTrackerClient =
	typeof(setmetatable(
		{} :: {
			_obj: IntValue,
			KillsChanged: RBXScriptSignal,
		},
		{} :: typeof({ __index = TeamKillTrackerClient })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new TeamKillTrackerClient. Should be done via the binder.

	@param tracker IntValue
	@return TeamKillTrackerClient
]=]
function TeamKillTrackerClient.new(tracker: IntValue): TeamKillTrackerClient
	local self: TeamKillTrackerClient = setmetatable(BaseObject.new(tracker) :: any, TeamKillTrackerClient)

	--[=[
	Fires when the kill count changes
	@prop KillsChanged RBXScriptSignal
	@within TeamKillTrackerClient
]=]
	self.KillsChanged = self._obj.Changed

	self._maid:GiveTask(TeamKillTrackerInterface.Client:Implement(self._obj, self))

	return self
end

--[=[
	Returns the value holding the kill count
	@return IntValue
]=]
function TeamKillTrackerClient.GetKillValue(self: TeamKillTrackerClient): IntValue
	return self._obj
end

--[=[
	Returns the team whose kills are tracked
	@return Instance?
]=]
function TeamKillTrackerClient.GetTeam(self: TeamKillTrackerClient): Instance?
	return self._obj.Parent
end

--[=[
	Returns the number of kills scored by the team
	@return number
]=]
function TeamKillTrackerClient.GetKills(self: TeamKillTrackerClient): number
	return self._obj.Value
end

--[=[
	Observes the number of kills scored by the team
]=]
function TeamKillTrackerClient.ObserveKills(self: TeamKillTrackerClient): Observable.Observable<number>
	return RxValueBaseUtils.observeValue(self._obj)
end

return Binder.new("TeamKillTracker", TeamKillTrackerClient :: any) :: Binder.Binder<TeamKillTrackerClient>
