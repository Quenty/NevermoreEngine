--[=[
	Utility functions involving [Animator] underneath a humanoid. These are used
	because the [Animator] is the preferred API surface by Roblox.

	@class HumanoidAnimatorUtils
]=]

local RunService = game:GetService("RunService")

local HumanoidAnimatorUtils = {}

--[=[
	Gets a humanoid animator for a given humanoid

	:::warning
	There is undefined behavior when using this on the client when the server
	does not already have an animator. Doing so may break replication. I'm not sure.
	:::

	@param humanoid Humanoid
	@return Animator
]=]
function HumanoidAnimatorUtils.getOrCreateAnimator(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		if RunService:IsClient() then
			warn(string.format("[HumanoidAnimatorUtils.getOrCreateAnimator] - Creating an animator on %s on the client", humanoid:GetFullName()))
		end

		animator = Instance.new("Animator")
		animator.Name = "Animator"
		animator.Parent = humanoid
	end

	return animator
end

--[=[
	Finds an animator in an instance

	@param target Instance
]=]
function HumanoidAnimatorUtils.findAnimator(target)
	return target:FindFirstChildOfClass("Animator")
end

--[=[
	Stops all animations from playing.

	@param humanoid Humanoid
	@param fadeTime number? -- Optional fade time to stop animations. Defaults to 0.1.
]=]
function HumanoidAnimatorUtils.stopAnimations(humanoid, fadeTime)
	for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
		track:Stop(fadeTime)
	end
end

--[=[
	Returns whether a track is being played.

	@param humanoid Humanoid
	@param track AnimationTrack
	@return boolean
]=]
function HumanoidAnimatorUtils.isPlayingAnimationTrack(humanoid, track)
	for _, playingTrack in pairs(humanoid:GetPlayingAnimationTracks()) do
		if playingTrack == track then
			return true
		end
	end

	return false
end


return HumanoidAnimatorUtils