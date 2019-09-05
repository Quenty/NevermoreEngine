--- Utility functions for animations
-- @module AnimationTrackUtils

local AnimationTrackUtils = {}

function AnimationTrackUtils.loadAnimationFromId(humanoid, animationId)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	return humanoid:LoadAnimation(animation)
end

function AnimationTrackUtils.setWeightTargetIfNotSet(track, weight, fadeTime)
	assert(track)
	assert(weight)
	assert(fadeTime)

	if track.WeightTarget ~= weight then
		track:AdjustWeight(weight, fadeTime)
	end
end

return AnimationTrackUtils