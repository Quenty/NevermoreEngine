--!strict
--[=[
	Counts the deaths of one player. Bound to every [Player] automatically through a
	[PlayerBinder]; every death report for that player increments a replicated [IntValue] kept
	under the player.

	Retrieve the binder from a [ServiceBag] with `serviceBag:GetService(require("PlayerDeathTracker"))`.

	@server
	@class PlayerDeathTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DeathReportService = require("DeathReportService")
local DeathReportServiceConstants = require("DeathReportServiceConstants")
local Observable = require("Observable")
local PlayerBinder = require("PlayerBinder")
local PlayerDeathTrackerInterface = require("PlayerDeathTrackerInterface")
local PlayerMock = require("PlayerMock")
local RxValueBaseUtils = require("RxValueBaseUtils")
local ServiceBag = require("ServiceBag")

local PlayerDeathTracker = setmetatable({}, BaseObject)
PlayerDeathTracker.ClassName = "PlayerDeathTracker"
PlayerDeathTracker.__index = PlayerDeathTracker

export type PlayerDeathTracker =
	typeof(setmetatable(
		{} :: {
			_obj: Player,
			_serviceBag: ServiceBag.ServiceBag,
			_deathReportService: DeathReportService.DeathReportService,
			_deathValue: IntValue,
		},
		{} :: typeof({ __index = PlayerDeathTracker })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerDeathTracker. Should be done via the binder.

	@param player Player
	@param serviceBag ServiceBag
	@return PlayerDeathTracker
]=]
function PlayerDeathTracker.new(player: Player, serviceBag: ServiceBag.ServiceBag): PlayerDeathTracker
	assert(typeof(player) == "Instance" and (player:IsA("Player") or PlayerMock.isMock(player)), "Bad player")

	local self: PlayerDeathTracker = setmetatable(BaseObject.new(player) :: any, PlayerDeathTracker)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._deathReportService = self._serviceBag:GetService(DeathReportService) :: any

	self._deathValue = self._maid:Add(Instance.new("IntValue"))
	self._deathValue.Name = DeathReportServiceConstants.PLAYER_DEATH_VALUE_NAME
	self._deathValue.Value = 0
	self._deathValue.Parent = self._obj

	self._maid:GiveTask(self._deathReportService:ObservePlayerDeathReports(self._obj):Subscribe(function(deathReport)
		assert(deathReport.player == self._obj, "Bad player")
		self._deathValue.Value = self._deathValue.Value + 1
	end))

	self._maid:GiveTask(PlayerDeathTrackerInterface.Server:Implement(self._obj, self))

	return self
end

--[=[
	Returns the replicated value holding the death count
	@return IntValue
]=]
function PlayerDeathTracker.GetDeathValue(self: PlayerDeathTracker): IntValue
	return self._deathValue
end

--[=[
	Returns the player whose deaths are tracked
	@return Player
]=]
function PlayerDeathTracker.GetPlayer(self: PlayerDeathTracker): Player
	return self._obj
end

--[=[
	Returns the number of deaths of the player
	@return number
]=]
function PlayerDeathTracker.GetDeaths(self: PlayerDeathTracker): number
	return self._deathValue.Value
end

--[=[
	Observes the number of deaths of the player
]=]
function PlayerDeathTracker.ObserveDeaths(self: PlayerDeathTracker): Observable.Observable<number>
	return RxValueBaseUtils.observeValue(self._deathValue)
end

return PlayerBinder.new(
		"PlayerDeathTracker",
		PlayerDeathTracker :: any
	) :: PlayerBinder.PlayerBinder<PlayerDeathTracker>
