--- Tracks the equipped player of a tool
-- @classmod EquippedTracker

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Maid = require("Maid")
local CharacterUtil = require("CharacterUtil")
local ValueObject = require("ValueObject")

local EquippedTracker = {}
EquippedTracker.ClassName = "EquippedTracker"
EquippedTracker.__index = EquippedTracker

function EquippedTracker.new(tool)
	local self = setmetatable({}, EquippedTracker)

	assert(tool and tool:IsA("Tool"))
	self._tool = tool

	self._maid = Maid.new()

	-- Tracks current equipped player who has an alive humanoid
	self.Player = ValueObject.new()
	self._maid:GiveTask(self.Player)

	self._maid:GiveTask(self._tool.Equipped:Connect(function()
		self:_update()
	end))
	self._maid:GiveTask(self._tool.Unequipped:Connect(function()
		self:_update()
	end))
	self:_update()

	return self
end

function EquippedTracker:_update()
	local player = CharacterUtil.GetPlayerFromCharacter(self._tool)
	if not player then
		self._maid._diedConn = nil
		self.Player.Value = nil
		return
	end

	local humanoid = CharacterUtil.GetAlivePlayerHumanoid(player)
	if not humanoid then
		self._maid._diedConn = nil
		self.Player.Value = nil
		return
	end

	self.Player.Value = player
	self._maid._diedConn = humanoid.Died:Connect(function()
		self:_update()
	end)
end

function EquippedTracker:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return EquippedTracker