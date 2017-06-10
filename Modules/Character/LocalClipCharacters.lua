local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local MakeMaid = LoadCustomLibrary("Maid").MakeMaid
local Hierarchy = LoadCustomLibrary("Hierarchy")

-- Intent: Hack to clip non-player characters locally

local LocalClipCharacters = {}
LocalClipCharacters.__index = LocalClipCharacters
LocalClipCharacters.ClassName = "LocalClipCharacters"

function LocalClipCharacters.new()
	local self = setmetatable({}, LocalClipCharacters)
	
	self.Maid = MakeMaid()
	self:BindUpdates()
	
	return self
end

function LocalClipCharacters:BindUpdates()
	local function OnPlayerAdded(Player)
		if Player ~= Players.LocalPlayer then
			local Maid = MakeMaid()
	
			local function OnCharacterAdded(Character)			
				local CharacterMaid = MakeMaid()
				local PreviousState = {}
				
				local function OnDescendantAdded(Item)
					if Item:IsA("BasePart") and Item.CanCollide then
						PreviousState[Item] = Item.CanCollide
						Item.CanCollide = false
					end
				end
				
				local function ForceReupdate()
					for Part, _ in pairs(PreviousState) do
						Part.CanCollide = false
					end
				end
				
				local function ResetCanCollide(Item)
					if Item:IsA("BasePart") and PreviousState[Item] ~= nil then
						Item.CanCollide = PreviousState[Item]
					end
				end
				
				Hierarchy.CallOnChildren(Character, OnDescendantAdded)
				CharacterMaid.OnDescendantAdded = Character.DescendantAdded:connect(OnDescendantAdded)
				CharacterMaid.Cleanup = function()
					Hierarchy.CallOnChildren(Character, ResetCanCollide)
				end
				CharacterMaid.Stepped = RunService.Stepped:connect(ForceReupdate)
				CharacterMaid.RenderStepped = RunService.RenderStepped:connect(ForceReupdate)
				
				Maid.CharacterMaid = CharacterMaid
			end
			
			Maid.CharacterAdded = Player.CharacterAdded:connect(OnCharacterAdded)
			if Player.Character then
				OnCharacterAdded(Player.Character)
			end

			self.Maid[Player] = Maid
		end
	end
	
	for _, Player in pairs(Players:GetPlayers()) do
		OnPlayerAdded(Player)
	end
	
	self.Maid.PlayerAdded = Players.PlayerAdded:connect(OnPlayerAdded)
	self.Maid.PlayerRemoved = Players.PlayerRemoving:connect(function(Player)
		self.Maid[Player] = nil
	end)
end

function LocalClipCharacters:Destroy()
	self.Maid:DoCleaning()
	self.Maid = nil
	
	setmetatable({}, nil)
end

return LocalClipCharacters