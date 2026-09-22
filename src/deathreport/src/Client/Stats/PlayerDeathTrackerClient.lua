--!strict
--[=[
	Client view of a [PlayerDeathTracker]: reads the replicated death count of a player.

	Retrieve the binder from a [ServiceBag] with `serviceBag:GetService(require("PlayerDeathTrackerClient"))`.

	@client
	@class PlayerDeathTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local ServiceBag = require("ServiceBag")

local PlayerDeathTrackerClient = setmetatable({}, BaseObject)
PlayerDeathTrackerClient.ClassName = "PlayerDeathTrackerClient"
PlayerDeathTrackerClient.__index = PlayerDeathTrackerClient

export type PlayerDeathTrackerClient =
	typeof(setmetatable(
		{} :: {
			_obj: IntValue,
			_serviceBag: ServiceBag.ServiceBag,
			DeathsChanged: RBXScriptSignal,
		},
		{} :: typeof({ __index = PlayerDeathTrackerClient })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerDeathTrackerClient. Should be done via the binder.

	@param tracker IntValue
	@param serviceBag ServiceBag
	@return PlayerDeathTrackerClient
]=]
function PlayerDeathTrackerClient.new(tracker: IntValue, serviceBag: ServiceBag.ServiceBag): PlayerDeathTrackerClient
	local self: PlayerDeathTrackerClient = setmetatable(BaseObject.new(tracker) :: any, PlayerDeathTrackerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	--[=[
	Fires when the death count changes
	@prop DeathsChanged RBXScriptSignal
	@within PlayerDeathTrackerClient
]=]
	self.DeathsChanged = self._obj.Changed

	return self
end

--[=[
	Returns the value holding the death count
	@return IntValue
]=]
function PlayerDeathTrackerClient.GetDeathValue(self: PlayerDeathTrackerClient): IntValue
	return self._obj
end

--[=[
	Returns the player whose deaths are tracked
	@return Instance?
]=]
function PlayerDeathTrackerClient.GetPlayer(self: PlayerDeathTrackerClient): Instance?
	return self._obj.Parent
end

--[=[
	Returns the number of deaths of the player
	@return number
]=]
function PlayerDeathTrackerClient.GetDeaths(self: PlayerDeathTrackerClient): number
	return self._obj.Value
end

--[=[
	Returns the number of deaths of the player

	@deprecated 10.60.0 -- Use [PlayerDeathTrackerClient.GetDeaths]
	@return number
]=]
function PlayerDeathTrackerClient.GetKills(self: PlayerDeathTrackerClient): number
	return self._obj.Value
end

return Binder.new("PlayerDeathTracker", PlayerDeathTrackerClient :: any) :: Binder.Binder<PlayerDeathTrackerClient>
