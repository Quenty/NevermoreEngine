---
-- @module HumanoidTrackerService
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")
local HumanoidTracker = require("HumanoidTracker")

local HumanoidTrackerService = {}

function HumanoidTrackerService:Init()
	self._humanoidTracker = HumanoidTracker.new(Players.LocalPlayer)
end

function HumanoidTrackerService:GetHumanoidTracker()
	assert(self._humanoidTracker, "Not initialized")

	return self._humanoidTracker
end

return HumanoidTrackerService