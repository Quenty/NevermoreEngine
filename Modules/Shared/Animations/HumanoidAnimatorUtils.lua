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

function HumanoidAnimatorUtils.stopAnimations(humanoid, fadeTime)
	for _, track in pairs(humanoid:GetPlayingAnimationTracks()) do
		if fadeTime == nil then
			track:Stop()
		else
			track:Stop(fadeTime)
		end
	end
end

return HumanoidAnimatorUtils
