--[=[
	A group of weighted tracks that can be played back with weighted probability.
	The closest example to this is the idle animation that looks around at a 1:10
	ratio when you're standing still in default Roblox animation script.

	@class AnimationGroup
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local AnimationGroupUtils = require("AnimationGroupUtils")
local Maid = require("Maid")

local AnimationGroup = setmetatable({}, BaseObject)
AnimationGroup.ClassName = "AnimationGroup"
AnimationGroup.__index = AnimationGroup

--[=[
	@param weightedTracks { WeightedTrack }
	@return AnimationGroup
]=]
function AnimationGroup.new(weightedTracks)
	local self = setmetatable(BaseObject.new(), AnimationGroup)

	self._weightedTracks = {}

	if weightedTracks then
		self:SetWeightedTracks(weightedTracks)
	end

	self._maid:GiveTask(function()
		self:Stop(0)
	end)

	return self
end

--[=[
	Plays the animations
	@param transitionTime number
]=]
function AnimationGroup:Play(transitionTime)
	assert(type(transitionTime) == "number" or transitionTime == nil, "Bad transitionTime")

	if self._currentTrack and self._currentTrack.IsPlaying then
		return
	end

	self:_playNewTrack(transitionTime)
end

--[=[
	@param weightedTracks { WeightedTrack }
	@param transitionTime number?
]=]
function AnimationGroup:SetWeightedTracks(weightedTracks, transitionTime)
	assert(type(weightedTracks) == "table", "Bad weightedTracks")
	assert(type(transitionTime) == "number" or transitionTime == nil, "Bad transitionTime")

	for _, animation in weightedTracks do
		assert(animation.track, "Bad animation.track")
		assert(animation.weight, "Bad animation.weight")
	end

	self._weightedTracks = weightedTracks

	self:Stop(transitionTime)
	self:Play(transitionTime)
end

--[=[
	Stops the animations
	@param transitionTime number
]=]
function AnimationGroup:Stop(transitionTime)
	assert(type(transitionTime) == "number" or transitionTime == nil, "Bad transitionTime")

	if self._currentTrack then
		self._currentTrack:Stop(transitionTime)
		self._currentTrack = nil
	end
end

function AnimationGroup:_playNewTrack(transitionTime)
	assert(type(transitionTime) == "number" or transitionTime == nil, "Bad transitionTime")

	local trackData = AnimationGroupUtils.selectFromWeightedTracks(self._weightedTracks)
	if not trackData then
		return
	end

	local track = trackData.track or error("No track")

	if self._currentTrack == track and self._currentTrack.IsPlaying then
		return
	end

	local maid = Maid.new()

	self:Stop(transitionTime)

	maid:GiveTask(track.KeyframeReached:Connect(function(...)
		self:_handleKeyframeReached(...)
	end))

	track:Play(transitionTime)

	self._currentTrack = track
	self._maid._trackMaid = maid
end

function AnimationGroup:_handleKeyframeReached(keyframeName)
	if keyframeName == "End" then
		self:_playNewTrack()
	end
end

return AnimationGroup