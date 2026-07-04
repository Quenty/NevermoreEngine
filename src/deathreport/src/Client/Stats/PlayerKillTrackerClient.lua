--!strict
--[=[
	@class PlayerKillTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
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

function PlayerKillTrackerClient.new(tracker: IntValue, serviceBag: ServiceBag.ServiceBag): PlayerKillTrackerClient
	local self: PlayerKillTrackerClient = setmetatable(BaseObject.new(tracker) :: any, PlayerKillTrackerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self.KillsChanged = self._obj.Changed

	return self
end

function PlayerKillTrackerClient.GetKillValue(self: PlayerKillTrackerClient): IntValue
	return self._obj
end

function PlayerKillTrackerClient.GetPlayer(self: PlayerKillTrackerClient): Instance?
	return self._obj.Parent
end

function PlayerKillTrackerClient.GetKills(self: PlayerKillTrackerClient): number
	return self._obj.Value
end

return PlayerKillTrackerClient
