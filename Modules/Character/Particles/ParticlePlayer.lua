--- Plays particle effects for players
-- @classmod ParticlePlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local ParticlePlayer = {}
ParticlePlayer.__index = ParticlePlayer
ParticlePlayer.ClassName = "ParticlePlayer"

function ParticlePlayer.new()
	local self = setmetatable({}, ParticlePlayer)

	return self
end

function ParticlePlayer:PlayLevelUpEffect(Humanoid)
	return self:PlayHumanoidEffect(Humanoid, ReplicatedStorage.Particles.LevelUpEffect)
end

function ParticlePlayer:PlayDescendantsOnce(Parent)
	local LongestLife = 0
	
	for _, Item in pairs(Parent:GetDescendants()) do
		if Item:IsA("ParticleEmitter") then
			Item:Emit(Item.Rate)
			LongestLife = math.max(LongestLife, Item.Lifetime.Max)
		end
	end
	
	return LongestLife
end

function ParticlePlayer:PlayHumanoidEffect(Humanoid, EffectTemplate)
	if not Humanoid then
		warn("[ParticlePlayer] - No Humanoid")
		return false
	end
	
	local RootPart = Humanoid.RootPart
	if not RootPart then
		warn("[ParticlePlayer] - No root part")
		return false
	end
	
	local Effect = EffectTemplate:Clone()
	local Core = Effect:FindFirstChild("Core")
	if not Core then
		warn("[ParticlePlayer] - No core")
		return false
	end
	
	for _, Child in pairs(Core:GetChildren()) do
		if Child:IsA("Attachment") then
			Child.Parent = RootPart
			
			local LongestTime = self:PlayDescendantsOnce(Child)
			Debris:AddItem(Child, LongestTime)
		end
	end
	
	-- Load animation
	spawn(function()
		local Animation = Instance.new("Animation")
		Animation.AnimationId = "rbxassetid://1097650171"
		
		local Track = Humanoid:LoadAnimation(Animation)
		Track:Play()
	end)
	
	-- Add non-core items to
	for _, Part in pairs(Effect:GetChildren()) do
		if Part ~= Core then
			local Relative = Core.CFrame:toObjectSpace(Part.CFrame)
			Part.CFrame = RootPart.CFrame:toWorldSpace(Relative)
			
			Part.CanCollide = false
			Part.Anchored = false
			--Part.Transparency = 1
			
			local Weld = Instance.new("Weld")
			Weld.Parent = Part
			Weld.Part0 = Part
			Weld.Part1 = RootPart
			Weld.C1 = Relative
			Weld.Name = "ParticleEmitterWeld"

			Part.Parent = Humanoid.Parent
			local LongestTime = self:PlayDescendantsOnce(Part)
			
			Debris:AddItem(Part, LongestTime)
		end
	end
	
	return true
end

return ParticlePlayer