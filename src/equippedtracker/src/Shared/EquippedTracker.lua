--[=[
	Tracks the equipped player of a tool
	@class EquippedTracker
]=]

local require = require(script.Parent.loader).load(script)

local CharacterUtils = require("CharacterUtils")
local Maid = require("Maid")
local ValueObject = require("ValueObject")

local EquippedTracker = {}
EquippedTracker.ClassName = "EquippedTracker"
EquippedTracker.__index = EquippedTracker

--[=[
	Tracks the state of a tool being equipped
	@param tool Tool
	@return EquippedTracker
]=]
function EquippedTracker.new(tool)
	local self = setmetatable({}, EquippedTracker)

	assert(tool and tool:IsA("Tool"), "Bad tool")
	self._tool = tool

	self._maid = Maid.new()

--[=[
	Tracks current equipped player who has an alive humanoid
	@prop Player ValueObject<Player>
	@within EquippedTracker
]=]
	self.Player = self._maid:Add(ValueObject.new(nil))

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
	local player = CharacterUtils.getPlayerFromCharacter(self._tool)
	if not player then
		self._maid._diedConn = nil
		self.Player.Value = nil
		return
	end

	local humanoid = CharacterUtils.getAlivePlayerHumanoid(player)
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

--[=[
	Cleans up the EquippedTracker
]=]
function EquippedTracker:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return EquippedTracker