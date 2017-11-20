local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local Signal = LoadCustomLibrary("Signal")

-- Intent: Makes playing and loading tracks into a humanoid easy

local AnimationPlayer = {}
AnimationPlayer.__index = AnimationPlayer
AnimationPlayer.ClassName = "AnimationPlayer"

function AnimationPlayer.new(Humanoid)
	local self = setmetatable({}, AnimationPlayer)
	
	self.Humanoid = Humanoid or error("No Humanoid")
	self.Tracks = {}
	self.FadeTime = 0.4 -- Default
	
	self.TrackPlayed = Signal.new()

	return self
end

function AnimationPlayer:WithAnimation(Animation)
	self.Tracks[Animation.Name] = self.Humanoid:LoadAnimation(Animation)

	return self
end

function AnimationPlayer:AddAnimation(Name, AnimationId)
	local Animation = Instance.new("Animation")

	if tonumber(AnimationId) then
		Animation.AnimationId = "http://www.roblox.com/Asset?ID=" .. tonumber(AnimationId) or error("No AnimationId")
	else
		Animation.AnimationId = AnimationId
	end

	Animation.Name = Name or error("No name")
	
	return self:WithAnimation(Animation)
end

function AnimationPlayer:GetTrack(TrackName)
	return self.Tracks[TrackName] or error("Track does not exist")
end

---
-- @param FadeTime How much time it will take to transition into the animation.	
-- @param Weight Acts as a multiplier for the offsets and rotations of the playing animation
	-- This parameter is extremely unstable. 
	-- Any parameter higher than 1.5 will result in very shaky motion, and any parameter higher '
	-- than 2 will almost always result in NAN errors. Use with caution.
-- @param Speed The time scale of the animation.	
	-- Setting this to 2 will make the animation 2x faster, and setting it to 0.5 will make it 
	-- run 2x slower.
function AnimationPlayer:PlayTrack(TrackName, FadeTime, Weight, Speed, StopFadeTime)
	FadeTime = FadeTime or self.FadeTime
	local Track = self:GetTrack(TrackName)

	if not Track.IsPlaying then
		self.TrackPlayed:fire(TrackName, FadeTime, Weight, Speed, StopFadeTime)

		self:StopAllTracks(StopFadeTime or FadeTime)
		Track:Play(FadeTime, Weight, Speed)
	end
	
	return Track
end

function AnimationPlayer:StopTrack(TrackName, FadeTime)
	FadeTime = FadeTime or self.FadeTime
	
	local Track = self:GetTrack(TrackName)
	
	Track:Stop(FadeTime)
	
	return Track
end

function AnimationPlayer:StopAllTracks(FadeTime)
	for TrackName, _ in pairs(self.Tracks) do
		self:StopTrack(TrackName, FadeTime)
	end
end

function AnimationPlayer:Destroy()
	self:StopAllTracks()
	setmetatable(self, nil)
end

return AnimationPlayer