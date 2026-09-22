--!strict
--[=[
	Counts the kills scored by one player. Bound to an [IntValue] parented under a [Player]; every
	death report whose killer is that player increments the value.

	Retrieve the binder from a [ServiceBag] with `serviceBag:GetService(require("PlayerKillTracker"))`
	and create tracked values with [PlayerKillTrackerUtils.create], or let
	[PlayerKillTrackerAssigner] do it for every player.

	@server
	@class PlayerKillTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local DeathReportService = require("DeathReportService")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

local PlayerKillTracker = setmetatable({}, BaseObject)
PlayerKillTracker.ClassName = "PlayerKillTracker"
PlayerKillTracker.__index = PlayerKillTracker

export type PlayerKillTracker =
	typeof(setmetatable(
		{} :: {
			_obj: IntValue,
			_serviceBag: ServiceBag.ServiceBag,
			_deathReportService: DeathReportService.DeathReportService,
			_player: Player,
		},
		{} :: typeof({ __index = PlayerKillTracker })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerKillTracker. Should be done via the binder.

	@param scoreObject IntValue -- Parented under the [Player] to track
	@param serviceBag ServiceBag
	@return PlayerKillTracker
]=]
function PlayerKillTracker.new(scoreObject: IntValue, serviceBag: ServiceBag.ServiceBag): PlayerKillTracker
	local self: PlayerKillTracker = setmetatable(BaseObject.new(scoreObject) :: any, PlayerKillTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService) :: any

	local player = self._obj.Parent
	assert(player and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")
	self._player = player :: Player

	self._maid:GiveTask(
		self._deathReportService:ObservePlayerKillerReports(self._player):Subscribe(function(deathReport)
			assert(deathReport.killerPlayer == self._player, "Bad player")
			self._obj.Value = self._obj.Value + 1
		end)
	)

	return self
end

--[=[
	Returns the value holding the kill count
	@return IntValue
]=]
function PlayerKillTracker.GetKillValue(self: PlayerKillTracker): IntValue
	return self._obj
end

--[=[
	Returns the player whose kills are tracked
	@return Player
]=]
function PlayerKillTracker.GetPlayer(self: PlayerKillTracker): Player
	return self._player
end

--[=[
	Returns the number of kills scored by the player
	@return number
]=]
function PlayerKillTracker.GetKills(self: PlayerKillTracker): number
	return self._obj.Value
end

return Binder.new("PlayerKillTracker", PlayerKillTracker :: any) :: Binder.Binder<PlayerKillTracker>
