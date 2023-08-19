--[=[
	@class SimpleLoopedSoundPlayer
]=]

local require = require(script.Parent.loader).load(script)

local TimedTransitionModel = require("TimedTransitionModel")
local Rx = require("Rx")
local SoundUtils = require("SoundUtils")
local SoundPromiseUtils = require("SoundPromiseUtils")
local Promise = require("Promise")
local ValueObject = require("ValueObject")

local SimpleLoopedSoundPlayer = setmetatable({}, TimedTransitionModel)
SimpleLoopedSoundPlayer.ClassName = "SimpleLoopedSoundPlayer"
SimpleLoopedSoundPlayer.__index = SimpleLoopedSoundPlayer

function SimpleLoopedSoundPlayer.new(soundId)
	local self = setmetatable(TimedTransitionModel.new(), SimpleLoopedSoundPlayer)

	self.Sound = SoundUtils.createSoundFromId(soundId)
	self.Sound.Looped = true
	self.Sound.Archivable = false
	self._maid:GiveTask(self.Sound)

	self:SetTransitionTime(1)

	self._volumeMultiplier = ValueObject.new(1, "number")
	self._maid:GiveTask(self._volumeMultiplier)

	self._maxVolume = self.Sound.Volume

	self._maid:GiveTask(Rx.combineLatest({
		visible = self:ObserveRenderStepped();
		multiplier = self._volumeMultiplier:Observe();
	}):Subscribe(function(state)
		self.Sound.Volume = state.visible*self._maxVolume*state.multiplier
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		if isVisible then
			self.Sound:Play()
		end
	end))

	return self
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