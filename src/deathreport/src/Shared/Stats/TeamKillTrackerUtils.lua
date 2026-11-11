--!strict
--[=[
	Helpers for creating and finding the [IntValue] a [TeamKillTracker] binds to.

	@class TeamKillTrackerUtils
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderUtils = require("BinderUtils")
local Brio = require("Brio")
local Observable = require("Observable")
local RxBinderUtils = require("RxBinderUtils")

local TeamKillTrackerUtils = {}

--[=[
	Creates a zeroed tracked value bound to the given binder. The caller parents it under the [Team]
	to track.

	@param binder Binder<T>
	@return IntValue
]=]
function TeamKillTrackerUtils.create<T>(binder: Binder.Binder<T>): IntValue
	local score = Instance.new("IntValue")
	score.Name = "TeamKillTracker"
	score.Value = 0

	binder:Bind(score)

	return score
end

--[=[
	Observes the bound tracker classes under the team

	@param binder Binder<T>
	@param team Instance
	@return Observable<Brio<T>>
]=]
function TeamKillTrackerUtils.observeBrio<T>(binder: Binder.Binder<T>, team: Instance): Observable.Observable<Brio.Brio<T>>
	assert(typeof(team) == "Instance", "Bad team")

	-- This ain't performant, but it's ok
	return RxBinderUtils.observeBoundChildClassBrio(binder, team)
end

--[=[
	Finds the first bound tracker class under the team

	@param binder Binder<T>
	@param team Instance
	@return T?
]=]
function TeamKillTrackerUtils.getTeamKillTracker<T>(binder: Binder.Binder<T>, team: Instance): T?
	return BinderUtils.findFirstChild(binder, team)
end

return TeamKillTrackerUtils
