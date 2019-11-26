---
-- @classmod AnimationGroup

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local AnimationGroupUtils = require("AnimationGroupUtils")
local Maid = require("Maid")

local AnimationGroup = setmetatable({}, BaseObject)
AnimationGroup.ClassName = "AnimationGroup"
AnimationGroup.__index = AnimationGroup

function AnimationGroup.new(weightedTracks)
	local self = setmetatable(BaseObject.new(), AnimationGroup)

	self._weightedTracks = weightedTracks or error("No tracksWithWeight")
	for _, animation in pairs(self._weightedTracks) do
		assert(animation.track)
		assert(animation.weight)
	end

	self._maid:GiveTask(function()
		self:Stop(0)
	end)

	return self
end

function AnimationGroup:Play(transitionTime)
	if self._currentTrack and self._currentTrack.IsPlaying then
		return
	end

	self:_playNewTrack(transitionTime)
end

function AnimationGroup:Stop(transitionTime)
	if self._currentTrack then
		self._currentTrack:Stop(transitionTime)
		self._currentTrack = nil
	end
end

function AnimationGroup:_playNewTrack(transitionTime)
	local trackData = AnimationGroupUtils.selectFromWeightedTracks(self._weightedTracks)
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