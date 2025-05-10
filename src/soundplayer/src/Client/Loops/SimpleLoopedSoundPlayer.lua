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

function SimpleLoopedSoundPlayer.new(soundId)
	local self = setmetatable(TimedTransitionModel.new(), SimpleLoopedSoundPlayer)

	self.Sound = self._maid:Add(SoundUtils.createSoundFromId(soundId))
	self.Sound.Looped = true
	self.Sound.Archivable = false

	self:SetTransitionTime(1)

	self._volumeMultiplier = self._maid:Add(ValueObject.new(1, "number"))

	self._maxVolume = self.Sound.Volume

	self._maid:GiveTask(Rx.combineLatest({
		visible = self:ObserveRenderStepped(),
		multiplier = self._volumeMultiplier:Observe(),
	}):Subscribe(function(state)
		self.Sound.Volume = state.visible * self._maxVolume * state.multiplier
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		if isVisible then
			self.Sound:Play()
		end
	end))

	return self
end

function SimpleLoopedSoundPlayer:SetSoundGroup(soundGroup)
	assert(typeof(soundGroup) == "Instance" or soundGroup == nil, "Bad soundGroup")

	self.Sound.SoundGroup = soundGroup
end

function SimpleLoopedSoundPlayer:SetVolumeMultiplier(volume)
	self._volumeMultiplier.Value = volume
end

function SimpleLoopedSoundPlayer:PromiseSustain()
	-- Never resolve
	return Promise.new()
end

function SimpleLoopedSoundPlayer:PromiseLoopDone()
	return SoundPromiseUtils.promiseLooped(self.Sound)
end

return SimpleLoopedSoundPlayer
