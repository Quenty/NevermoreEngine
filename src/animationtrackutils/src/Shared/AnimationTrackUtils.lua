--[=[
	Utility functions for animations
	@class AnimationTrackUtils
]=]

local AnimationTrackUtils = {}

--[=[
	Loads an animation from the animation id
	@param humanoid Humanoid
	@param animationId string
	@return Animation
]=]
function AnimationTrackUtils.loadAnimationFromId(humanoid, animationId)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	return humanoid:LoadAnimation(animation)
end

--[=[
	Sets the weight target if not set
	@param track AnimationTrack
	@param weight number
	@param fadeTime number
	@return Animation
]=]
function AnimationTrackUtils.setWeightTargetIfNotSet(track, weight, fadeTime)
	assert(typeof(track) == "Instance", "Bad track")
	assert(type(weight) == "number", "Bad weight")
	assert(type(fadeTime) == "number", "Bad fadeTime")

	if track.WeightTarget ~= weight then
		track:AdjustWeight(weight, fadeTime)
	end
end

return AnimationTrackUtils