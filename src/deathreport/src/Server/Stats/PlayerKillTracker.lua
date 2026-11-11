--!strict
--[=[
	Counts the kills scored by one player. Bound to every [Player] automatically through a
	[PlayerBinder]; every death report whose killer is that player increments a replicated
	[IntValue] kept under the player.

	Retrieve the binder from a [ServiceBag] with `serviceBag:GetService(require("PlayerKillTracker"))`.

	@server
	@class PlayerKillTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DeathReportService = require("DeathReportService")
local DeathReportServiceConstants = require("DeathReportServiceConstants")
local Observable = require("Observable")
local PlayerBinder = require("PlayerBinder")
local PlayerKillTrackerInterface = require("PlayerKillTrackerInterface")
local PlayerMock = require("PlayerMock")
local RxValueBaseUtils = require("RxValueBaseUtils")
local ServiceBag = require("ServiceBag")

local PlayerKillTracker = setmetatable({}, BaseObject)
PlayerKillTracker.ClassName = "PlayerKillTracker"
PlayerKillTracker.__index = PlayerKillTracker

export type PlayerKillTracker =
	typeof(setmetatable(
		{} :: {
			_obj: Player,
			_serviceBag: ServiceBag.ServiceBag,
			_deathReportService: DeathReportService.DeathReportService,
			_killValue: IntValue,
		},
		{} :: typeof({ __index = PlayerKillTracker })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerKillTracker. Should be done via the binder.

	@param player Player
	@param serviceBag ServiceBag
	@return PlayerKillTracker
]=]
function PlayerKillTracker.new(player: Player, serviceBag: ServiceBag.ServiceBag): PlayerKillTracker
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	local self: PlayerKillTracker = setmetatable(BaseObject.new(player) :: any, PlayerKillTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService) :: any

	self._killValue = self._maid:Add(Instance.new("IntValue"))
	self._killValue.Name = DeathReportServiceConstants.PLAYER_KILL_VALUE_NAME
	self._killValue.Value = 0
	self._killValue.Parent = self._obj

	self._maid:GiveTask(self._deathReportService:ObservePlayerKillerReports(self._obj):Subscribe(function(deathReport)
		assert(deathReport.killerPlayer == self._obj, "Bad player")
		self._killValue.Value = self._killValue.Value + 1
	end))

	self._maid:GiveTask(PlayerKillTrackerInterface.Server:Implement(self._obj, self))

	return self
end

--[=[
	Returns the replicated value holding the kill count
	@return IntValue
]=]
function PlayerKillTracker.GetKillValue(self: PlayerKillTracker): IntValue
	return self._killValue
end

--[=[
	Returns the player whose kills are tracked
	@return Player
]=]
function PlayerKillTracker.GetPlayer(self: PlayerKillTracker): Player
	return self._obj
end

--[=[
	Returns the number of kills scored by the player
	@return number
]=]
function PlayerKillTracker.GetKills(self: PlayerKillTracker): number
	return self._killValue.Value
end

--[=[
	Observes the number of kills scored by the player
]=]
function PlayerKillTracker.ObserveKills(self: PlayerKillTracker): Observable.Observable<number>
	return RxValueBaseUtils.observeValue(self._killValue)
end

return PlayerBinder.new("PlayerKillTracker", PlayerKillTracker :: any) :: PlayerBinder.PlayerBinder<PlayerKillTracker>
