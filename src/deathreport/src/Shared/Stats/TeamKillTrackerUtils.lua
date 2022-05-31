--[=[
	@class TeamKillTrackerUtils
]=]

local require = require(script.Parent.loader).load(script)

local BinderUtils = require("BinderUtils")
local RxBinderUtils = require("RxBinderUtils")

local TeamKillTrackerUtils = {}

function TeamKillTrackerUtils.create(binder)
	local score = Instance.new("IntValue")
	score.Name = "TeamKillTracker"
	score.Value = 0

	binder:Bind(score)

	return score
end

function TeamKillTrackerUtils.observeBrio(binder, player)
	assert(typeof(player) == "Instance", "Bad player")

	-- This ain't performant, but it's ok
	return RxBinderUtils.observeBoundChildClassBrio(binder, player)
end

function TeamKillTrackerUtils.getTeamKillTracker(binder, team)
	return BinderUtils.findFirstChild(binder, team)
end

return TeamKillTrackerUtils