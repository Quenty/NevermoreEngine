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
	local GroupId = PhysicsService:CreateCollisionGroup(ClipCharacters.CollisionGroupName)
	PhysicsService:CollisionGroupSetCollidable(ClipCharacters.CollisionGroupName, "Default", false)
	
	local RemoteFunction = require.GetRemoteFunction("GetClipCharactersId")
	function RemoteFunction.OnServerInvoke(Player)
		return GroupId
	end
end

--- Initialize clipping on the client. Returns a new inst
-- @constructor
-- @treturn ClipCharacters
function ClipCharacters.new()
	local self = setmetatable({}, ClipCharacters)

	self.RemoteFunction = require.GetRemoteFunction("GetClipCharactersId")

	self.Maid = Maid.new()
	self:BindUpdatesYielding()

	return self
end

function ClipCharacters:_onDescendantAdded(OriginalTable, Descendant)
	if not OriginalTable[Descendant] and Descendant:IsA("BasePart") then
		OriginalTable[Descendant] = Descendant.CollisionGroupId
		Descendant.CollisionGroupId = self.CollisionGroupId
	end
end

function ClipCharacters:_onDescendantRemoving(OriginalTable, Descendant)
	if OriginalTable[Descendant] then
		Descendant.CollisionGroupId = OriginalTable[Descendant]
		OriginalTable[Descendant] = nil
	end
end

function ClipCharacters:_onCharacterAdd(PlayerMaid, Character)
	local maid = Maid.new()

	local OriginalTable = {}

	maid:GiveTask(Character.DescendantAdded:Connect(function(Descendant)
		self:_onDescendantAdded(OriginalTable, Descendant)
	end))

	maid:GiveTask(Character.DescendantRemoving:Connect(function(Descendant)
		self:_onDescendantRemoving(OriginalTable, Descendant)
	end))

	-- Cleanup
	maid:GiveTask(function()
		for Descendant, _ in pairs(OriginalTable) do
			self:_onDescendantRemoving(OriginalTable, Descendant)
		end
	end)

	-- Initialize
	for _, Descendant in pairs(Character:GetDescendants()) do
		self:_onDescendantAdded(OriginalTable, Descendant)
	end

	PlayerMaid.CharacterMaid = maid
end

function ClipCharacters:_onPlayerAdded(Player)
	if Player == Players.LocalPlayer then
		return
	end

	local maid = Maid.new()

	maid:GiveTask(Player.CharacterAdded:Connect(function(Character)
		self:_onCharacterAdd(maid, Character)
	end))

	if Player.Character then
		self:_onCharacterAdd(maid, Player.Character)
	end

	self.Maid[Player] = maid
end

function ClipCharacters:BindUpdatesYielding()
	self.CollisionGroupId = self.RemoteFunction:InvokeServer()
	
	if not self.CollisionGroupId then
		warn("[ClipCharacters] - No self.CollisionGroupId")
	end
	
	for _, Player in pairs(Players:GetPlayers()) do
		self:_onPlayerAdded(Player)
	end
	
	self.Maid:GiveTask(Players.PlayerAdded:Connect(function(Player)
		self:_onPlayerAdded(Player)
	end))
	
	self.Maid:GiveTask(Players.PlayerRemoving:Connect(function(Player)
		self.Maid[Player] = nil
	end))
end

--- Stop clipping on client
-- @treturn nil
function ClipCharacters:Destroy()
	self.Maid:DoCleaning()
	self.Maid = nil
	
	setmetatable({}, nil)
end

return ClipCharacters