--!strict
--[=[
	Tracks a player's current team, since the Team property is unreliable
	@class TeamTracker
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local ValueObject = require("ValueObject")

local TeamTracker = {}
TeamTracker.ClassName = "TeamTracker"
TeamTracker.__index = TeamTracker

export type TeamTracker = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_player: Player,

		CurrentTeam: ValueObject.ValueObject<Team?>,
	},
	{} :: typeof({ __index = TeamTracker })
))

function TeamTracker.new(player: Player): TeamTracker
	local self = setmetatable({}, TeamTracker)

	self._player = assert(player, "No player")
	self._maid = Maid.new()

	self.CurrentTeam = self._maid:Add(ValueObject.new(nil)) -- Holds a Roblox team

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

function TeamTracker.GetPlayer(self: TeamTracker): Player
	return self._player
end

function TeamTracker._updateCurrentTeam(self: TeamTracker)
	if self._player.Neutral then
		self.CurrentTeam.Value = nil
		return
	end

	self.CurrentTeam.Value = self._player.Team
end

function TeamTracker.Destroy(self: TeamTracker)
	self._maid:DoCleaning()
	setmetatable(self :: any, nil)
end

return TeamTracker
