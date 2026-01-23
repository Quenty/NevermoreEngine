--!strict
--[=[
	Plays a single track, allowing for the animation to be controlled easier.

	@class AnimationTrackPlayer
]=]

local require = require(script.Parent.loader).load(script)

local AnimationUtils = require("AnimationUtils")
local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Rx = require("Rx")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local AnimationTrackPlayer = setmetatable({}, BaseObject)
AnimationTrackPlayer.ClassName = "AnimationTrackPlayer"
AnimationTrackPlayer.__index = AnimationTrackPlayer

type AnimationId = string | number

export type AnimationTrackPlayer =
	typeof(setmetatable(
		{} :: {
			-- Public
			KeyframeReached: Signal.Signal<string>,

			-- Private
			_animationTarget: ValueObject.ValueObject<Instance?>,
			_trackId: ValueObject.ValueObject<AnimationId?>,
			_currentTrack: ValueObject.ValueObject<AnimationTrack?>,
			_animationPriority: ValueObject.ValueObject<number?>,
		},
		{} :: typeof({ __index = AnimationTrackPlayer })
	))
	& BaseObject.BaseObject

--[=[
	Plays an animation track in the target. Async loads the track when
	all data is found.
]=]
function AnimationTrackPlayer.new(
	animationTarget: ValueObject.Mountable<Instance?>,
	animationId: AnimationId?
): AnimationTrackPlayer
	local self: AnimationTrackPlayer = setmetatable(BaseObject.new() :: any, AnimationTrackPlayer)

	self._animationTarget = self._maid:Add(ValueObject.new(nil))
	self._trackId = self._maid:Add(ValueObject.new(nil))
	self._currentTrack = self._maid:Add(ValueObject.new(nil))
	self._animationPriority = self._maid:Add(ValueObject.new(nil))

	self.KeyframeReached = self._maid:Add(Signal.new() :: any)

	if animationTarget then
		self:SetAnimationTarget(animationTarget)
	end

	if animationId then
		self:SetAnimationId(animationId)
	end

	self:_setupState()

	return self
end

function AnimationTrackPlayer._setupState(self: AnimationTrackPlayer): ()
	self._maid:GiveTask(Rx.combineLatest({
		animationTarget = self._animationTarget:Observe(),
		trackId = self._trackId:Observe(),
		animationPriority = self._animationPriority:Observe(),
	})
		:Pipe({
			Rx.throttleDefer() :: any,
		})
		:Subscribe(function(state)
			if state.animationTarget and state.trackId then
				self._currentTrack.Value = AnimationUtils.getOrCreateAnimationTrack(
					state.animationTarget,
					state.trackId,
					state.animationPriority
				)
			else
				self._currentTrack.Value = nil
			end
		end))

	self._maid:GiveTask(self._currentTrack
		:ObserveBrio(function(track)
			return track ~= nil
		end)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid = brio:ToMaid()
			local track = brio:GetValue() :: AnimationTrack

			maid:GiveTask(track.KeyframeReached:Connect(function(...)
				self.KeyframeReached:Fire(...)
			end))
		end))
end

--[=[
	Sets the animation id to play
]=]
function AnimationTrackPlayer.SetAnimationId(
	self: AnimationTrackPlayer,
	animationId: ValueObject.Mountable<AnimationId?>
): Maid.MaidTask
	return self._trackId:Mount(animationId)
end

--[=[
	Returns the current animation id
]=]
function AnimationTrackPlayer.GetAnimationId(self: AnimationTrackPlayer): AnimationId?
	return self._trackId.Value
end

--[=[
	Sets an animation target to play the animation on
]=]
function AnimationTrackPlayer.SetAnimationTarget(
	self: AnimationTrackPlayer,
	animationTarget: ValueObject.Mountable<Instance?>
): Maid.MaidTask
	return self._animationTarget:Mount(animationTarget)
end

--[=[
	Sets the weight target if it hasn't been set
]=]
function AnimationTrackPlayer.SetWeightTargetIfNotSet(
	self: AnimationTrackPlayer,
	weight: number?,
	fadeTime: number?
): ()
	self._maid._adjustWeight = self:_onEachTrack(function(track: AnimationTrack)
		if track.WeightTarget ~= weight then
			track:AdjustWeight(weight, fadeTime)
		end
	end)
end

--[=[
	Plays the current animation specified
]=]
function AnimationTrackPlayer.Play(self: AnimationTrackPlayer, fadeTime: number?, weight: number?, speed: number): ()
	if weight then
		self._maid._adjustWeight = nil
	end

	if speed then
		self._maid._adjustSpeed = nil
	end

	self._maid._stop = nil
	self._maid._play = self:_onEachTrack(function(track: AnimationTrack)
		track:Play(fadeTime, weight, speed)
	end)
end

--[=[
	Stops the current animation
]=]
function AnimationTrackPlayer.Stop(self: AnimationTrackPlayer, fadeTime: number?): ()
	self._maid._play = nil
	self._maid._stop = self:_onEachTrack(function(track: AnimationTrack)
		track:Stop(fadeTime)
	end)
end

--[=[
	Adjusts the weight of the animation track
]=]
function AnimationTrackPlayer.AdjustWeight(self: AnimationTrackPlayer, weight: number?, fadeTime: number?): ()
	self._maid._adjustWeight = self:_onEachTrack(function(track: AnimationTrack)
		track:AdjustWeight(weight, fadeTime)
	end)
end

--[=[
	Adjusts the speed of the animation track
]=]
function AnimationTrackPlayer.AdjustSpeed(self: AnimationTrackPlayer, speed: number?): ()
	self._maid._adjustSpeed = self:_onEachTrack(function(track: AnimationTrack)
		track:AdjustSpeed(speed)
	end)
end

--[=[
	Returns true if playing
]=]
function AnimationTrackPlayer.IsPlaying(self: AnimationTrackPlayer): boolean
	local track: AnimationTrack? = self._currentTrack.Value
	if track then
		return track.IsPlaying
	else
		return false
	end
end

function AnimationTrackPlayer._onEachTrack(self: AnimationTrackPlayer, callback)
	return self._currentTrack:Observe():Subscribe(function(track: AnimationTrack?)
		if track ~= nil then
			callback(track)
		end
	end)
end

return AnimationTrackPlayer
