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

	@param humanoid Humanoid | AnimationController
	@return Animator
]=]
function HumanoidAnimatorUtils.getOrCreateAnimator(humanoid: Humanoid | AnimationController): Animator
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator ~= nil then
		return animator
	end

	if RunService:IsClient() then
		warn(
			string.format(
				"[HumanoidAnimatorUtils.getOrCreateAnimator] - Creating an animator on %s on the client",
				humanoid:GetFullName()
			)
		)
	end

	local newAnimator = Instance.new("Animator")
	newAnimator.Name = "Animator"
	newAnimator.Parent = humanoid
	return newAnimator
end

--[=[
	Finds an animator in an instance

	@param target Instance
]=]
function HumanoidAnimatorUtils.findAnimator(target: Instance): Animator?
	return target:FindFirstChildOfClass("Animator")
end

--[=[
	Stops all animations from playing.

	@param humanoid Humanoid
	@param fadeTime number? -- Optional fade time to stop animations. Defaults to 0.1.
]=]
function HumanoidAnimatorUtils.stopAnimations(humanoid: Humanoid, fadeTime: number)
	local animator = HumanoidAnimatorUtils.getOrCreateAnimator(humanoid)

	for _, track in animator:GetPlayingAnimationTracks() do
		track:Stop(fadeTime)
	end
end

--[=[
	Returns whether a track is being played.

	@param humanoid Humanoid
	@param track AnimationTrack
	@return boolean
]=]
function HumanoidAnimatorUtils.isPlayingAnimationTrack(humanoid: Humanoid, track: AnimationTrack): boolean
	local animator = HumanoidAnimatorUtils.getOrCreateAnimator(humanoid)

	for _, playingTrack in animator:GetPlayingAnimationTracks() do
		if playingTrack == track then
			return true
		end
	end

	return false
end


return HumanoidAnimatorUtils