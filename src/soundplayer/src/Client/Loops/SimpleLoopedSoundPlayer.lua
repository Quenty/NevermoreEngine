--!strict
--[=[
	@class SimpleLoopedSoundPlayer
]=]

local require = require(script.Parent.loader).load(script)

local Promise = require("Promise")
local Rx = require("Rx")
local SoundPromiseUtils = require("SoundPromiseUtils")
local SoundUtils = require("SoundUtils")
local TimedTransitionModel = require("TimedTransitionModel")
local ValueObject = require("ValueObject")

local SimpleLoopedSoundPlayer = setmetatable({}, TimedTransitionModel)
SimpleLoopedSoundPlayer.ClassName = "SimpleLoopedSoundPlayer"
SimpleLoopedSoundPlayer.__index = SimpleLoopedSoundPlayer

export type SimpleLoopedSoundPlayer =
	typeof(setmetatable(
		{} :: {
			Sound: Sound,
			_volumeMultiplier: ValueObject.ValueObject<number>,
			_maxVolume: number,
		},
		{} :: typeof({ __index = SimpleLoopedSoundPlayer })
	))
	& TimedTransitionModel.TimedTransitionModel

function SimpleLoopedSoundPlayer.new(soundId: SoundUtils.SoundId): SimpleLoopedSoundPlayer
	local self: SimpleLoopedSoundPlayer = setmetatable(TimedTransitionModel.new() :: any, SimpleLoopedSoundPlayer)

	self.Sound = self._maid:Add(SoundUtils.createSoundFromId(soundId))
	self.Sound.Looped = true
	self.Sound.Archivable = false

	self:SetTransitionTime(1)

	self._volumeMultiplier = self._maid:Add(ValueObject.new(1, "number"))

	self._maxVolume = self.Sound.Volume

	self._maid:GiveTask(Rx.combineLatest({
		visible = self:ObserveRenderStepped(),
		multiplier = self._volumeMultiplier:Observe(),
	}):Subscribe(function(state: any)
		self.Sound.Volume = state.visible * self._maxVolume * state.multiplier
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		if isVisible then
			self.Sound:Play()
		end
	end))

	return self
end

--[=[
	Sets the SoundGroup of the internal Sound.
	@param soundGroup SoundGroup?
]=]
function SimpleLoopedSoundPlayer.SetSoundGroup(self: SimpleLoopedSoundPlayer, soundGroup: SoundGroup?): ()
	assert(typeof(soundGroup) == "Instance" or soundGroup == nil, "Bad soundGroup")

	self.Sound.SoundGroup = soundGroup
end

--[=[
	Sets the volume multiplier for the sound player.
]=]
function SimpleLoopedSoundPlayer.SetVolumeMultiplier(self: SimpleLoopedSoundPlayer, volume: number): ()
	self._volumeMultiplier.Value = volume
end

--[=[
	Promises indefinitely until the sound player is destroyed.
]=]
function SimpleLoopedSoundPlayer.PromiseSustain(self: SimpleLoopedSoundPlayer): Promise.Promise<()>
	-- Never resolve
	return self._maid:GivePromise(Promise.new())
end

--[=[
	Promises until the current loop is done.
]=]
function SimpleLoopedSoundPlayer.PromiseLoopDone(self: SimpleLoopedSoundPlayer): Promise.Promise<()>
	return SoundPromiseUtils.promiseLooped(self.Sound)
end

return SimpleLoopedSoundPlayer
