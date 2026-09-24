--!strict
--[=[
	Client view of a [PlayerKillTracker]: reads the kill count the server replicates under the
	player. Binds to every tagged [Player].

	Retrieve the binder from a [ServiceBag] with `serviceBag:GetService(require("PlayerKillTrackerClient"))`.

	@client
	@class PlayerKillTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local DeathReportServiceConstants = require("DeathReportServiceConstants")
local Observable = require("Observable")
local PlayerKillTrackerInterface = require("PlayerKillTrackerInterface")
local Rx = require("Rx")
local RxValueBaseUtils = require("RxValueBaseUtils")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")

local PlayerKillTrackerClient = setmetatable({}, BaseObject)
PlayerKillTrackerClient.ClassName = "PlayerKillTrackerClient"
PlayerKillTrackerClient.__index = PlayerKillTrackerClient

export type PlayerKillTrackerClient =
	typeof(setmetatable(
		{} :: {
			_obj: Player,
			_serviceBag: ServiceBag.ServiceBag,
			KillsChanged: Signal.Signal<number>,
		},
		{} :: typeof({ __index = PlayerKillTrackerClient })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerKillTrackerClient. Should be done via the binder.

	@param player Player
	@param serviceBag ServiceBag
	@return PlayerKillTrackerClient
]=]
function PlayerKillTrackerClient.new(player: Player, serviceBag: ServiceBag.ServiceBag): PlayerKillTrackerClient
	local self: PlayerKillTrackerClient = setmetatable(BaseObject.new(player) :: any, PlayerKillTrackerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	--[=[
	Fires with the new kill count whenever it changes
	@prop KillsChanged Signal<number>
	@within PlayerKillTrackerClient
]=]
	self.KillsChanged = self._maid:Add(Signal.new()) :: any

	self._maid:GiveTask(self:ObserveKills():Pipe({ Rx.skip(1) :: any }):Subscribe(function(kills)
		self.KillsChanged:Fire(kills)
	end))

	self._maid:GiveTask(PlayerKillTrackerInterface.Client:Implement(self._obj, self))

	return self
end

--[=[
	Returns the replicated value holding the kill count, once it has streamed in
	@return IntValue?
]=]
function PlayerKillTrackerClient.GetKillValue(self: PlayerKillTrackerClient): IntValue?
	local value = self._obj:FindFirstChild(DeathReportServiceConstants.PLAYER_KILL_VALUE_NAME)
	if value and value:IsA("IntValue") then
		return value
	end

	return nil
end

--[=[
	Returns the player whose kills are tracked
	@return Player
]=]
function PlayerKillTrackerClient.GetPlayer(self: PlayerKillTrackerClient): Player
	return self._obj
end

--[=[
	Returns the number of kills scored by the player, 0 until the value has replicated
	@return number
]=]
function PlayerKillTrackerClient.GetKills(self: PlayerKillTrackerClient): number
	local value = self:GetKillValue()
	return if value then value.Value else 0
end

--[=[
	Observes the number of kills scored by the player. Emits 0 until the value has replicated.
]=]
function PlayerKillTrackerClient.ObserveKills(self: PlayerKillTrackerClient): Observable.Observable<number>
	return RxValueBaseUtils.observe(
			self._obj,
			"IntValue",
			DeathReportServiceConstants.PLAYER_KILL_VALUE_NAME,
			0
		)
			:Pipe({
				Rx.defaultsTo(0) :: any,
				Rx.distinct() :: any,
			}) :: any
end

return Binder.new("PlayerKillTracker", PlayerKillTrackerClient :: any) :: Binder.Binder<PlayerKillTrackerClient>
