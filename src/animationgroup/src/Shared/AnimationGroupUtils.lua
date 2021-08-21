---
-- @module AnimationGroupUtils

local require = require(script.Parent.loader).load(script)

local AnimationTrackUtils = require("AnimationTrackUtils")

local AnimationGroupUtils = {}

function AnimationGroupUtils.createdWeightedTracks(humanoid, weightedAnimationList)
	assert(humanoid, "Bad humanoid")
	assert(weightedAnimationList, "Bad weightedAnimationList")

	local tracks = {}
	for _, weightedAnimation in pairs(weightedAnimationList) do
		assert(weightedAnimation.animationId, "Bad weightedAnimation.animationId")
		assert(weightedAnimation.weight, "Bad weightedAnimation.weight")

		table.insert(tracks, AnimationGroupUtils.createdWeightedTrack(
			AnimationTrackUtils.loadAnimationFromId(humanoid, weightedAnimation.animationId),
			weightedAnimation.weight))
	end
	return tracks
end

function AnimationGroupUtils.createdWeightedAnimation(animationId, weight)
	assert(type(animationId) == "string", "Bad animationId")
	assert(type(weight) == "number", "Bad weight")

	return {
		animationId = animationId;
		weight = weight;
	}
end

function AnimationGroupUtils.createdWeightedTrack(track, weight)
	assert(typeof(track) == "Instance" and track:IsA("AnimationTrack"), "Bad track")
	assert(type(weight) == "number", "Bad weight")

	return {
		track = track;
		weight = weight;
	}
end

function AnimationGroupUtils.selectFromWeightedTracks(weightedTracks)
	assert(type(weightedTracks) == "table", "Bad weightedTracks")
	assert(#weightedTracks > 0, "Bad weightedTracks")

	if #weightedTracks == 1 then
		return weightedTracks[1]
	end

	local totalWeight = 0
	for _, animationData in pairs(weightedTracks) do
		totalWeight = totalWeight + animationData.weight
	end

	assert(totalWeight ~= 0, "total weight is 0")

	local selection = math.random()

	local total = 0
	for _, option in pairs(weightedTracks) do
		local threshold = total + option.weight/totalWeight
		total = total + threshold

		if selection <= threshold then
			return option
		end
	end

	error(("[AnimationGroupUtils.selectFromWeightedTracks] - Failed to find a selection with option at %d")
		:format(selection))
	return nil
end

return AnimationGroupUtils