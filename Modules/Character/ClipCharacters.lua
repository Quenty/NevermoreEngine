local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local NevermoreEngine = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid = LoadCustomLibrary("Maid").MakeMaid

--[[
class ClipCharacters

Description:
Clip characters locally on the client of other clients so they don't interfer with physics

API:
	ClipCharacters.initServer()
		Initialize on server

	ClipCharacters.new()
		Initialize clipping on the client. Returns a new inst

	ClipCharaters:Destroy()
		Stop clipping on client
]]

local ClipCharacters = {}
ClipCharacters.ClassName = "ClipCharacters"
ClipCharacters.__index = ClipCharacters
ClipCharacters.CollisionGroupName = "ClipCharacters"

function ClipCharacters.initServer()
	local GroupId = PhysicsService:CreateCollisionGroup(ClipCharacters.CollisionGroupName)
	PhysicsService:CollisionGroupSetCollidable(ClipCharacters.CollisionGroupName, "Default", false)
	
	local RemoteFunction = NevermoreEngine.GetRemoteFunction("GetClipCharactersId")
	function RemoteFunction.OnServerInvoke(Player)
		return GroupId
	end
end

function ClipCharacters.new()
	local self = setmetatable({}, ClipCharacters)

	self.RemoteFunction = NevermoreEngine.GetRemoteFunction("GetClipCharactersId")

	self.Maid = MakeMaid()
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
	local Maid = MakeMaid()

	local OriginalTable = {}

	Maid:GiveTask(Character.DescendantAdded:connect(function(Descendant)
		self:_onDescendantAdded(OriginalTable, Descendant)
	end))

	Maid:GiveTask(Character.DescendantRemoving:connect(function(Descendant)
		self:_onDescendantRemoving(OriginalTable, Descendant)
	end))

	-- Cleanup
	Maid:GiveTask(function()
		for Descendant, _ in pairs(OriginalTable) do
			self:_onDescendantRemoving(OriginalTable, Descendant)
		end
	end)

	-- Initialize
	for _, Descendant in pairs(Character:GetDescendants()) do
		self:_onDescendantAdded(OriginalTable, Descendant)
	end

	PlayerMaid.CharacterMaid = Maid
end

function ClipCharacters:_onPlayerAdded(Player)
	if Player == Players.LocalPlayer then
		return
	end

	local Maid = MakeMaid()

	Maid:GiveTask(Player.CharacterAdded:connect(function(Character)
		self:_onCharacterAdd(Maid, Character)
	end))

	if Player.Character then
		self:_onCharacterAdd(Maid, Player.Character)
	end

	self.Maid[Player] = Maid
end

function ClipCharacters:BindUpdatesYielding()
	self.CollisionGroupId = self.RemoteFunction:InvokeServer()
	
	if not self.CollisionGroupId then
		warn("[ClipCharacters] - No self.CollisionGroupId")
	end
	
	for _, Player in pairs(Players:GetPlayers()) do
		self:_onPlayerAdded(Player)
	end
	
	self.Maid:GiveTask(Players.PlayerAdded:connect(function(Player)
		self:_onPlayerAdded(Player)
	end))
	
	self.Maid:GiveTask(Players.PlayerRemoving:connect(function(Player)
		self.Maid[Player] = nil
	end))
end

function ClipCharacters:Destroy()
	self.Maid:DoCleaning()
	self.Maid = nil
	
	setmetatable({}, nil)
end

return ClipCharacters