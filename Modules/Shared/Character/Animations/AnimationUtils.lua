--- Utility functions for animations
-- @module AnimationUtils

local AnimationUtils = {}

function AnimationUtils.loadAnimationFromId(humanoid, animationId)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	return humanoid:LoadAnimation(animation)
end

return AnimationUtils