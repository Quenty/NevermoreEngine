--!strict
--[=[
	Plays particle effects for players

	@deprecated 2.2.2
	@class ParticlePlayer
]=]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ParticlePlayer = {}
ParticlePlayer.__index = ParticlePlayer
ParticlePlayer.ClassName = "ParticlePlayer"

export type ParticlePlayer = typeof(setmetatable({} :: {}, {} :: typeof({ __index = ParticlePlayer })))

function ParticlePlayer.new(): ParticlePlayer
	local self: ParticlePlayer = setmetatable({} :: any, ParticlePlayer)

	return self
end

function ParticlePlayer.PlayLevelUpEffect(self: ParticlePlayer, humanoid: Humanoid): boolean
	if not humanoid then
		warn("[ParticlePlayer] - No humanoid")
		return false
	end

	-- Load animation
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://1097650171"

	local track = (humanoid :: any):LoadAnimation(animation)
	track:Play()

	return self:_playHumanoidEffect(humanoid, (ReplicatedStorage :: any).Particles.LevelUpEffect)
end

function ParticlePlayer._playDescendantsOnce(_self: ParticlePlayer, parent: Instance): number
	local longestLife = 0

	for _, item in parent:GetDescendants() do
		if item:IsA("ParticleEmitter") then
			item:Emit(item.Rate)
			longestLife = math.max(longestLife, item.Lifetime.Max)
		end
	end

	return longestLife
end

function ParticlePlayer._playHumanoidEffect(self: ParticlePlayer, humanoid: Humanoid, effectTemplate: Instance): boolean
	local rootPart = humanoid.RootPart
	if not rootPart then
		warn("[ParticlePlayer] - No root part")
		return false
	end

	local effect = effectTemplate:Clone()
	local core = effect:FindFirstChild("Core")
	if not core then
		warn("[ParticlePlayer] - No core")
		return false
	end

	for _, child in core:GetChildren() do
		if child:IsA("Attachment") then
			child.Parent = rootPart

			local longestTime = self:_playDescendantsOnce(child)
			Debris:AddItem(child, longestTime)
		end
	end

	-- Add non-core items to
	for _, part in effect:GetChildren() do
		if part ~= core then
			local basePart = part :: BasePart
			local relative = (core :: BasePart).CFrame:ToObjectSpace(basePart.CFrame)
			basePart.CFrame = rootPart.CFrame:ToWorldSpace(relative)

			basePart.CanCollide = false
			basePart.Anchored = false
			--part.Transparency = 1

			local weld = Instance.new("Weld")
			weld.Parent = basePart
			weld.Part0 = basePart
			weld.Part1 = rootPart
			weld.C1 = relative
			weld.Name = "ParticleEmitterWeld"

			basePart.Parent = humanoid.Parent
			local longestTime = self:_playDescendantsOnce(basePart)

			Debris:AddItem(basePart, longestTime)
		end
	end

	return true
end

return ParticlePlayer
