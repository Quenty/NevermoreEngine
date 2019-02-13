--- Clip characters locally on the client of other clients so they don't interfer with physics.
-- @classmod ClipCharacters

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Maid = require("Maid")

local ClipCharacters = {}
ClipCharacters.ClassName = "ClipCharacters"
ClipCharacters.__index = ClipCharacters
ClipCharacters.CollisionGroupName = "ClipCharacters"

--- Initialize on server
-- @constructor
-- @treturn nil
function ClipCharacters.initServer()
	local groupId = PhysicsService:CreateCollisionGroup(ClipCharacters.CollisionGroupName)
	PhysicsService:CollisionGroupSetCollidable(ClipCharacters.CollisionGroupName, "Default", false)

	local remoteFunction = require.GetRemoteFunction("GetClipCharactersId")
	function remoteFunction.OnServerInvoke(player)
		return groupId
	end
end

--- Initialize clipping on the client. Returns a new inst
-- @constructor
-- @treturn ClipCharacters
function ClipCharacters.new()
	local self = setmetatable({}, ClipCharacters)

	self._remoteFunction = require.GetRemoteFunction("GetClipCharactersId")

	self._maid = Maid.new()
	self:_bindUpdatesYielding()

	return self
end

function ClipCharacters:_onDescendantAdded(originalTable, descendant)
	if not originalTable[descendant] and descendant:IsA("BasePart") then
		originalTable[descendant] = descendant.CollisionGroupId
		descendant.CollisionGroupId = self._collisionGroupId
	end
end

function ClipCharacters:_onDescendantRemoving(originalTable, descendant)
	if originalTable[descendant] then
		descendant.CollisionGroupId = originalTable[descendant]
		originalTable[descendant] = nil
	end
end

function ClipCharacters:_onCharacterAdd(playerMaid, character)
	local maid = Maid.new()

	local originalTable = {}

	maid:GiveTask(character.DescendantAdded:Connect(function(descendant)
		self:_onDescendantAdded(originalTable, descendant)
	end))

	maid:GiveTask(character.DescendantRemoving:Connect(function(descendant)
		self:_onDescendantRemoving(originalTable, descendant)
	end))

	-- Cleanup
	maid:GiveTask(function()
		for descendant, _ in pairs(originalTable) do
			self:_onDescendantRemoving(originalTable, descendant)
		end
	end)

	-- Initialize
	for _, descendant in pairs(character:GetDescendants()) do
		self:_onDescendantAdded(originalTable, descendant)
	end

	playerMaid._characterMaid = maid
end

function ClipCharacters:_onPlayerAdded(player)
	if player == Players.LocalPlayer then
		return
	end

	local maid = Maid.new()

	maid:GiveTask(player.CharacterAdded:Connect(function(character)
		self:_onCharacterAdd(maid, character)
	end))

	if player.Character then
		self:_onCharacterAdd(maid, player.Character)
	end

	self._maid[player] = maid
end

function ClipCharacters:_bindUpdatesYielding()
	self._collisionGroupId = self._remoteFunction:InvokeServer()

	if not self._collisionGroupId then
		warn("[ClipCharacters] - No self._collisionGroupId")
	end

	for _, player in pairs(Players:GetPlayers()) do
		self:_onPlayerAdded(player)
	end

	self._maid:GiveTask(Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end))

	self._maid:GiveTask(Players.PlayerRemoving:Connect(function(player)
		self._maid[player] = nil
	end))
end

--- Stop clipping on client
-- @treturn nil
function ClipCharacters:Destroy()
	self._maid:DoCleaning()
	self._maid = nil

	setmetatable({}, nil)
end

return ClipCharacters