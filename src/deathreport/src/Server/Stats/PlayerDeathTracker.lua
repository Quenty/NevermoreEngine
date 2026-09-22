--!strict
--[=[
	Counts the deaths of one player. Bound to an [IntValue] parented under a [Player]; every death
	report for that player increments the value.

	Retrieve the binder from a [ServiceBag] with `serviceBag:GetService(require("PlayerDeathTracker"))`
	and create tracked values with [PlayerKillTrackerUtils.create], or let
	[PlayerKillTrackerAssigner] do it for every player.

	@server
	@class PlayerDeathTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local DeathReportService = require("DeathReportService")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")

local PlayerDeathTracker = setmetatable({}, BaseObject)
PlayerDeathTracker.ClassName = "PlayerDeathTracker"
PlayerDeathTracker.__index = PlayerDeathTracker

export type PlayerDeathTracker =
	typeof(setmetatable(
		{} :: {
			_obj: IntValue,
			_serviceBag: ServiceBag.ServiceBag,
			_deathReportService: DeathReportService.DeathReportService,
			_player: Player,
		},
		{} :: typeof({ __index = PlayerDeathTracker })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerDeathTracker. Should be done via the binder.

	@param scoreObject IntValue -- Parented under the [Player] to track
	@param serviceBag ServiceBag
	@return PlayerDeathTracker
]=]
function PlayerDeathTracker.new(scoreObject: IntValue, serviceBag: ServiceBag.ServiceBag): PlayerDeathTracker
	local self: PlayerDeathTracker = setmetatable(BaseObject.new(scoreObject) :: any, PlayerDeathTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService) :: any

	local player = self._obj.Parent
	assert(player and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")
	self._player = player :: Player

	self._maid:GiveTask(self._deathReportService:ObservePlayerDeathReports(self._player):Subscribe(function(deathReport)
		assert(deathReport.player == self._player, "Bad player")
		self._obj.Value = self._obj.Value + 1
	end))

	return self
end

--[=[
	Returns the value holding the death count
	@return IntValue
]=]
function PlayerDeathTracker.GetDeathValue(self: PlayerDeathTracker): IntValue
	return self._obj
end

--[=[
	Returns the player whose deaths are tracked
	@return Player
]=]
function PlayerDeathTracker.GetPlayer(self: PlayerDeathTracker): Player
	return self._player
end

--[=[
	Returns the number of deaths of the player
	@return number
]=]
function PlayerDeathTracker.GetDeaths(self: PlayerDeathTracker): number
	return self._obj.Value
end

return Binder.new("PlayerDeathTracker", PlayerDeathTracker :: any) :: Binder.Binder<PlayerDeathTracker>
