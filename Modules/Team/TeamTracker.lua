--- Tracks a player's current team, since the Team property is unreliable
-- @classmod TeamTracker

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")
local ValueObject = require("ValueObject")

local TeamTracker = {}
TeamTracker.ClassName = "TeamTracker"
TeamTracker.__index = TeamTracker

function TeamTracker.new(player)
	local self = setmetatable({}, TeamTracker)

	self._player = player or error("No player")

	self._maid = Maid.new()

	self.CurrentTeam = ValueObject.new() -- Holds a Roblox team
	self.CurrentTeam.Value = nil
	self._maid:GiveTask(self.CurrentTeam)

	self._maid:GiveTask(self._player:GetPropertyChangedSignal("TeamColor"):Connect(function()
		self:_updateCurrentTeam()
	end))
	self._maid:GiveTask(self._player:GetPropertyChangedSignal("Neutral"):Connect(function()
		self:_updateCurrentTeam()
	end))
	self._maid:GiveTask(self._player:GetPropertyChangedSignal("Team"):Connect(function()
		self:_updateCurrentTeam()
	end))
	self:_updateCurrentTeam()

	return self
end

function TeamTracker:GetPlayer()
	return self._player
end

function TeamTracker:_updateCurrentTeam()
	if self._player.Neutral then
		self.CurrentTeam.Value = nil
		return
	end

	self.CurrentTeam.Value = self._player.Team
end

function TeamTracker:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return TeamTracker