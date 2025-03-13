--[=[
	An animation group is a group of animations, such as the idle animations that Roblox plays.
	This utility functions are intended to help recreate a custom animation playback system with
	weighted values.
	@class AnimationGroupUtils
]=]

local require = require(script.Parent.loader).load(script)

local AnimationTrackUtils = require("AnimationTrackUtils")

local AnimationGroupUtils = {}

--[=[
	@interface WeightedAnimation
	.animationId string
	.weight number
	@within AnimationGroupUtils
]=]

--[=[
	@interface WeightedTrack
	.track Track
	.weight number
	@within AnimationGroupUtils
]=]

--[=[
	Creates a new weighted track list.
	@param animatorOrHumanoid Humanoid | Animator
	@param weightedAnimationList { WeightedAnimation }
	@return { WeightedTrack }
]=]
function AnimationGroupUtils.createdWeightedTracks(animatorOrHumanoid, weightedAnimationList)
	assert(animatorOrHumanoid, "Bad animatorOrHumanoid")
	assert(weightedAnimationList, "Bad weightedAnimationList")

	local tracks = {}

	for _, weightedAnimation in weightedAnimationList do
		assert(weightedAnimation.animationId, "Bad weightedAnimation.animationId")
		assert(weightedAnimation.weight, "Bad weightedAnimation.weight")

		table.insert(
			tracks,
			AnimationGroupUtils.createdWeightedTrack(
				AnimationTrackUtils.loadAnimationFromId(animatorOrHumanoid, weightedAnimation.animationId),
				weightedAnimation.weight
			)
		)
	end

	return tracks
end

--[=[
	Creates a new weighted animation.

	@param animationId string
	@param weight number
	@return WeightedAnimation
]=]
function AnimationGroupUtils.createdWeightedAnimation(animationId, weight)
	assert(type(animationId) == "string", "Bad animationId")
	assert(type(weight) == "number", "Bad weight")

	return {
		animationId = animationId,
		weight = weight,
	}
end

--[=[
	Creates a new weighted track.

	@param track Track
	@param weight number
	@return WeightedTrack
]=]
function AnimationGroupUtils.createdWeightedTrack(track, weight)
	assert(typeof(track) == "Instance" and track:IsA("AnimationTrack"), "Bad track")
	assert(type(weight) == "number", "Bad weight")

	return {
		track = track,
		weight = weight,
	}
end

--[=[
	Picks a weighted track for playback.

	@param weightedTracks { WeightedTrack }
	@return WeightedTrack?
]=]
function AnimationGroupUtils.selectFromWeightedTracks(weightedTracks)
	assert(type(weightedTracks) == "table", "Bad weightedTracks")
	assert(#weightedTracks > 0, "Bad weightedTracks")

	if #weightedTracks == 1 then
		return weightedTracks[1]
	end

	local totalWeight = 0
	for _, animationData in weightedTracks do
		totalWeight = totalWeight + animationData.weight
	end

	assert(totalWeight ~= 0, "total weight is 0")

	local selection = math.random()

	local total = 0
	for _, option in weightedTracks do
		local threshold = total + option.weight/totalWeight
		total = total + threshold

		if selection <= threshold then
			return option
		end
	end

	error(string.format("[AnimationGroupUtils.selectFromWeightedTracks] - Failed to find a selection with option at %d", selection))
	return nil
end

return AnimationGroupUtils