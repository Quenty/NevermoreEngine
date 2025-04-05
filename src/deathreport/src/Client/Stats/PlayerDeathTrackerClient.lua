--[=[
	@class PlayerDeathTrackerClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local _ServiceBag = require("ServiceBag")

local PlayerDeathTrackerClient = setmetatable({}, BaseObject)
PlayerDeathTrackerClient.ClassName = "PlayerDeathTrackerClient"
PlayerDeathTrackerClient.__index = PlayerDeathTrackerClient

function PlayerDeathTrackerClient.new(tracker, serviceBag: _ServiceBag.ServiceBag)
	local self = setmetatable(BaseObject.new(tracker), PlayerDeathTrackerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self.DeathsChanged = self._obj.Changed

	return self
end

function PlayerDeathTrackerClient:GetDeathValue()
	return self._obj
end

function PlayerDeathTrackerClient:GetPlayer()
	return self._obj.Parent
end

function PlayerDeathTrackerClient:GetKills()
	return self._obj.Value
end

return PlayerDeathTrackerClient