---
-- @classmod PlayerHumanoidBinder
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Players = game:GetService("Players")
local Binder = require("Binder")
local Maid = require("Maid")
local HumanoidTracker = require("HumanoidTracker")

local PlayerHumanoidBinder = setmetatable({}, Binder)
PlayerHumanoidBinder.ClassName = "PlayerHumanoidBinder"
PlayerHumanoidBinder.__index = PlayerHumanoidBinder

function PlayerHumanoidBinder.new(tag, class)
	local self = setmetatable(Binder.new(tag, class), PlayerHumanoidBinder)

	self._playerMaid = Maid.new()
	self._maid:GiveTask(self._playerMaid)

	return self
end

function PlayerHumanoidBinder:Start()
	local results = { getmetatable(PlayerHumanoidBinder).Start(self) }

	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:_handlePlayerAdded(player)
	end))
	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self:_handlePlayerRemoving(player)
	end))

	for _, item in pairs(Players:GetPlayers()) do
		self:_handlePlayerAdded(item)
	end

	return unpack(results)
end

function PlayerHumanoidBinder:_handlePlayerAdded(player)
	local maid = Maid.new()
	self._playerMaid[player] = maid

	local tracker = HumanoidTracker.new(player)
	maid:GiveTask(tracker)

	maid:GiveTask(tracker.Humanoid.Changed:Connect(function(newHumanoid)
		if newHumanoid then
			self:Bind(newHumanoid)
		end
	end))

	-- Bind humanoid
	do
		local currentHumanoid = tracker.Humanoid.Value
		if currentHumanoid then
			self:Bind(currentHumanoid)
		end
	end
end

function PlayerHumanoidBinder:_handlePlayerRemoving(player)
	self._playerMaid[player] = nil
end


return PlayerHumanoidBinder