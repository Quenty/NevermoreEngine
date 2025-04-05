--[=[
	@class PlayerKillTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local _ServiceBag = require("ServiceBag")

local PlayerKillTrackerClient = setmetatable({}, BaseObject)
PlayerKillTrackerClient.ClassName = "PlayerKillTrackerClient"
PlayerKillTrackerClient.__index = PlayerKillTrackerClient

function PlayerKillTrackerClient.new(tracker, serviceBag: _ServiceBag.ServiceBag)
	local self = setmetatable(BaseObject.new(tracker), PlayerKillTrackerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self.KillsChanged = self._obj.Changed

	return self
end

function PlayerKillTrackerClient:GetKillValue()
	return self._obj
end

function PlayerKillTrackerClient:GetPlayer()
	return self._obj.Parent
end

function PlayerKillTrackerClient:GetKills()
	return self._obj.Value
end

return PlayerKillTrackerClient