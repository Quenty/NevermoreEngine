--!strict
--[=[
	Helpers for creating and finding the [IntValue] a [PlayerKillTracker] or [PlayerDeathTracker]
	binds to.

	@class PlayerKillTrackerUtils
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local BinderUtils = require("BinderUtils")
local Brio = require("Brio")
local Observable = require("Observable")
local PlayerMock = require("PlayerMock")
local RxBinderUtils = require("RxBinderUtils")

local PlayerKillTrackerUtils = {}

--[=[
	Creates a tracked value under the player and binds it to the given binder

	@param binder Binder<T>
	@param player Player
	@return IntValue
]=]
function PlayerKillTrackerUtils.create<T>(binder: Binder.Binder<T>, player: Player): IntValue
	assert(typeof(player) == "Instance", "Bad player")

	local score = Instance.new("IntValue")
	score.Name = "PlayerKillTracker"
	score.Value = 0

	binder:Bind(score)

	score.Parent = player

	return score
end

--[=[
	Observes the bound tracker classes under the player

	@param binder Binder<T>
	@param player Player
	@return Observable<Brio<T>>
]=]
function PlayerKillTrackerUtils.observeBrio<T>(
	binder: Binder.Binder<T>,
	player: Player
): Observable.Observable<Brio.Brio<T>>
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	-- This ain't performant, but it's ok
	return RxBinderUtils.observeBoundChildClassBrio(binder, player)
end

--[=[
	Finds the first bound tracker class under the player

	@param binder Binder<T>
	@param player Player
	@return T?
]=]
function PlayerKillTrackerUtils.getPlayerKillTracker<T>(binder: Binder.Binder<T>, player: Instance): T?
	return BinderUtils.findFirstChild(binder, player)
end

return PlayerKillTrackerUtils
