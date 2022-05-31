--[=[
	@class PlayerKillTrackerUtils
]=]

local require = require(script.Parent.loader).load(script)

local BinderUtils = require("BinderUtils")
local RxBinderUtils = require("RxBinderUtils")

local PlayerKillTrackerUtils = {}

function PlayerKillTrackerUtils.create(binder, player)
	assert(typeof(player) == "Instance", "Bad player")

	local score = Instance.new("IntValue")
	score.Name = "PlayerKillTracker"
	score.Value = 0

	binder:Bind(score)

	score.Parent = player

	return score
end

function PlayerKillTrackerUtils.observeBrio(binder, player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	-- This ain't performant, but it's ok
	return RxBinderUtils.observeBoundChildClassBrio(binder, player)
end

function PlayerKillTrackerUtils.getPlayerKillTracker(binder, team)
	return BinderUtils.findFirstChild(binder, team)
end

return PlayerKillTrackerUtils