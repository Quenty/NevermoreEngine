--!strict
--[=[
	Client view of a [PlayerDeathTracker]: reads the death count the server replicates under the
	player. Binds to every tagged [Player].

	Retrieve the binder from a [ServiceBag] with `serviceBag:GetService(require("PlayerDeathTrackerClient"))`.

	@client
	@class PlayerDeathTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local DeathReportServiceConstants = require("DeathReportServiceConstants")
local Observable = require("Observable")
local PlayerDeathTrackerInterface = require("PlayerDeathTrackerInterface")
local Rx = require("Rx")
local RxValueBaseUtils = require("RxValueBaseUtils")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")

local PlayerDeathTrackerClient = setmetatable({}, BaseObject)
PlayerDeathTrackerClient.ClassName = "PlayerDeathTrackerClient"
PlayerDeathTrackerClient.__index = PlayerDeathTrackerClient

export type PlayerDeathTrackerClient =
	typeof(setmetatable(
		{} :: {
			_obj: Player,
			_serviceBag: ServiceBag.ServiceBag,
			DeathsChanged: Signal.Signal<number>,
		},
		{} :: typeof({ __index = PlayerDeathTrackerClient })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerDeathTrackerClient. Should be done via the binder.

	@param player Player
	@param serviceBag ServiceBag
	@return PlayerDeathTrackerClient
]=]
function PlayerDeathTrackerClient.new(player: Player, serviceBag: ServiceBag.ServiceBag): PlayerDeathTrackerClient
	local self: PlayerDeathTrackerClient = setmetatable(BaseObject.new(player) :: any, PlayerDeathTrackerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	--[=[
	Fires with the new death count whenever it changes
	@prop DeathsChanged Signal<number>
	@within PlayerDeathTrackerClient
]=]
	self.DeathsChanged = self._maid:Add(Signal.new()) :: any

	self._maid:GiveTask(self:ObserveDeaths():Pipe({ Rx.skip(1) :: any }):Subscribe(function(deaths)
		self.DeathsChanged:Fire(deaths)
	end))

	self._maid:GiveTask(PlayerDeathTrackerInterface.Client:Implement(self._obj, self))

	return self
end

--[=[
	Returns the replicated value holding the death count, once it has streamed in
	@return IntValue?
]=]
function PlayerDeathTrackerClient.GetDeathValue(self: PlayerDeathTrackerClient): IntValue?
	local value = self._obj:FindFirstChild(DeathReportServiceConstants.PLAYER_DEATH_VALUE_NAME)
	if value and value:IsA("IntValue") then
		return value
	end

	return nil
end

--[=[
	Returns the player whose deaths are tracked
	@return Player
]=]
function PlayerDeathTrackerClient.GetPlayer(self: PlayerDeathTrackerClient): Player
	return self._obj
end

--[=[
	Returns the number of deaths of the player, 0 until the value has replicated
	@return number
]=]
function PlayerDeathTrackerClient.GetDeaths(self: PlayerDeathTrackerClient): number
	local value = self:GetDeathValue()
	return if value then value.Value else 0
end

--[=[
	Returns the number of deaths of the player

	@deprecated 10.60.0 -- Use [PlayerDeathTrackerClient.GetDeaths]
	@return number
]=]
function PlayerDeathTrackerClient.GetKills(self: PlayerDeathTrackerClient): number
	return self:GetDeaths()
end

--[=[
	Observes the number of deaths of the player. Emits 0 until the value has replicated.
]=]
function PlayerDeathTrackerClient.ObserveDeaths(self: PlayerDeathTrackerClient): Observable.Observable<number>
	return RxValueBaseUtils.observe(
			self._obj,
			"IntValue",
			DeathReportServiceConstants.PLAYER_DEATH_VALUE_NAME,
			0
		)
			:Pipe({
				Rx.defaultsTo(0) :: any,
				Rx.distinct() :: any,
			}) :: any
end

return Binder.new("PlayerDeathTracker", PlayerDeathTrackerClient :: any) :: Binder.Binder<PlayerDeathTrackerClient>
