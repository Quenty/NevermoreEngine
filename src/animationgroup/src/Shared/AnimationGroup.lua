--!strict
--[=[
	A group of weighted tracks that can be played back with weighted probability.
	The closest example to this is the idle animation that looks around at a 1:10
	ratio when you're standing still in default Roblox animation script.

	@class AnimationGroup
]=]

local require = require(script.Parent.loader).load(script)

local AnimationGroupUtils = require("AnimationGroupUtils")
local BaseObject = require("BaseObject")
local Maid = require("Maid")

local AnimationGroup = setmetatable({}, BaseObject)
AnimationGroup.ClassName = "AnimationGroup"
AnimationGroup.__index = AnimationGroup

export type AnimationGroup = typeof(setmetatable(
	{} :: {
		_weightedTracks: { AnimationGroupUtils.WeightedTrack },
		_currentTrack: AnimationTrack?,
	},
	{} :: typeof({ __index = AnimationGroup })
)) & BaseObject.BaseObject

--[=[
	@param weightedTracks { WeightedTrack }
	@return AnimationGroup
]=]
function AnimationGroup.new(weightedTracks: { AnimationGroupUtils.WeightedTrack }): AnimationGroup
	local self: AnimationGroup = setmetatable(BaseObject.new() :: any, AnimationGroup)

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
function AnimationGroup.Play(self: AnimationGroup, transitionTime: number?): ()
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
function AnimationGroup.SetWeightedTracks(
	self: AnimationGroup,
	weightedTracks: { AnimationGroupUtils.WeightedTrack },
	transitionTime: number?
)
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

	@param transitionTime number?
]=]
function AnimationGroup.Stop(self: AnimationGroup, transitionTime: number?): ()
	assert(type(transitionTime) == "number" or transitionTime == nil, "Bad transitionTime")

	if self._currentTrack then
		self._currentTrack:Stop(transitionTime)
		self._currentTrack = nil
	end
end

function AnimationGroup._playNewTrack(self: AnimationGroup, transitionTime: number?)
	assert(type(transitionTime) == "number" or transitionTime == nil, "Bad transitionTime")

	local trackData = AnimationGroupUtils.selectFromWeightedTracks(self._weightedTracks)
	if not trackData then
		return
	end

	local track = assert(trackData.track, "No track")

	if self._currentTrack == track and self._currentTrack and self._currentTrack.IsPlaying then
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

function AnimationGroup._handleKeyframeReached(self: AnimationGroup, keyframeName: string)
	if keyframeName == "End" then
		self:_playNewTrack()
	end
end

return AnimationGroup
