--!strict
--[=[
	@class PlayerDeathTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ServiceBag = require("ServiceBag")

local PlayerDeathTrackerClient = setmetatable({}, BaseObject)
PlayerDeathTrackerClient.ClassName = "PlayerDeathTrackerClient"
PlayerDeathTrackerClient.__index = PlayerDeathTrackerClient

export type PlayerDeathTrackerClient =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			DeathsChanged: RBXScriptSignal,
		},
		{} :: typeof({ __index = PlayerDeathTrackerClient })
	))
	& BaseObject.BaseObject

function PlayerDeathTrackerClient.new(tracker: IntValue, serviceBag: ServiceBag.ServiceBag): PlayerDeathTrackerClient
	local self: PlayerDeathTrackerClient = setmetatable(BaseObject.new(tracker) :: any, PlayerDeathTrackerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self.DeathsChanged = (self._obj :: IntValue).Changed

	return self
end

function PlayerDeathTrackerClient.GetDeathValue(self: PlayerDeathTrackerClient): IntValue
	return self._obj :: IntValue
end

function PlayerDeathTrackerClient.GetPlayer(self: PlayerDeathTrackerClient): Instance?
	return (self._obj :: IntValue).Parent
end

function PlayerDeathTrackerClient.GetKills(self: PlayerDeathTrackerClient): number
	return (self._obj :: IntValue).Value
end

return PlayerDeathTrackerClient
