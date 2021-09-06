---
-- @module HumanoidTrackerService
-- @author Quenty

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local HumanoidTracker = require("HumanoidTracker")

local HumanoidTrackerService = {}

function HumanoidTrackerService:Init()
	assert(not self._humanoidTracker, "Already initialized")

	self._humanoidTracker = HumanoidTracker.new(Players.LocalPlayer)
end

function HumanoidTrackerService:GetHumanoidTracker()
	assert(self._humanoidTracker, "Not initialized")

	return self._humanoidTracker
end

return HumanoidTrackerService