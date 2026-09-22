--!strict
--[=[
	Client view of a [PlayerKillTracker]: reads the replicated kill count of a player.

	Retrieve the binder from a [ServiceBag] with `serviceBag:GetService(require("PlayerKillTrackerClient"))`.

	@client
	@class PlayerKillTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Binder = require("Binder")
local ServiceBag = require("ServiceBag")

local PlayerKillTrackerClient = setmetatable({}, BaseObject)
PlayerKillTrackerClient.ClassName = "PlayerKillTrackerClient"
PlayerKillTrackerClient.__index = PlayerKillTrackerClient

export type PlayerKillTrackerClient =
	typeof(setmetatable(
		{} :: {
			_obj: IntValue,
			_serviceBag: ServiceBag.ServiceBag,
			KillsChanged: RBXScriptSignal,
		},
		{} :: typeof({ __index = PlayerKillTrackerClient })
	))
	& BaseObject.BaseObject

--[=[
	Constructs a new PlayerKillTrackerClient. Should be done via the binder.

	@param tracker IntValue
	@param serviceBag ServiceBag
	@return PlayerKillTrackerClient
]=]
function PlayerKillTrackerClient.new(tracker: IntValue, serviceBag: ServiceBag.ServiceBag): PlayerKillTrackerClient
	local self: PlayerKillTrackerClient = setmetatable(BaseObject.new(tracker) :: any, PlayerKillTrackerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	--[=[
	Fires when the kill count changes
	@prop KillsChanged RBXScriptSignal
	@within PlayerKillTrackerClient
]=]
	self.KillsChanged = self._obj.Changed

	return self
end

--[=[
	Returns the value holding the kill count
	@return IntValue
]=]
function PlayerKillTrackerClient.GetKillValue(self: PlayerKillTrackerClient): IntValue
	return self._obj
end

--[=[
	Returns the player whose kills are tracked
	@return Instance?
]=]
function PlayerKillTrackerClient.GetPlayer(self: PlayerKillTrackerClient): Instance?
	return self._obj.Parent
end

--[=[
	Returns the number of kills scored by the player
	@return number
]=]
function PlayerKillTrackerClient.GetKills(self: PlayerKillTrackerClient): number
	return self._obj.Value
end

return Binder.new("PlayerKillTracker", PlayerKillTrackerClient :: any) :: Binder.Binder<PlayerKillTrackerClient>
