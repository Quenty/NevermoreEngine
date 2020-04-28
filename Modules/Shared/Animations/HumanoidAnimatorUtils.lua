---
-- @module HumanoidAnimatorUtils

local HumanoidAnimatorUtils = {}

function HumanoidAnimatorUtils.getOrCreateAnimator(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "Animator"
		animator.Parent = humanoid
	end

	return animator
end

function HumanoidAnimatorUtils.stopAnimations(humanoid)
	for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
		track:Stop()
	end
end

return HumanoidAnimatorUtils