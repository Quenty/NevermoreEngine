--[=[
	@class LayeredLoopedSoundPlayer
]=]

local require = require(script.Parent.loader).load(script)

local LoopedSoundPlayer = require("LoopedSoundPlayer")
local Maid = require("Maid")
local Rx = require("Rx")
local SoundLoopScheduleUtils = require("SoundLoopScheduleUtils")
local SoundUtils = require("SoundUtils")
local SpringTransitionModel = require("SpringTransitionModel")
local ValueObject = require("ValueObject")
local t = require("t")

local LayeredLoopedSoundPlayer = setmetatable({}, SpringTransitionModel)
LayeredLoopedSoundPlayer.ClassName = "LayeredLoopedSoundPlayer"
LayeredLoopedSoundPlayer.__index = LayeredLoopedSoundPlayer

function LayeredLoopedSoundPlayer.new(soundParent)
	local self = setmetatable(SpringTransitionModel.new(), LayeredLoopedSoundPlayer)

	self._layerMaid = self._maid:Add(Maid.new())

	self._soundParent = self._maid:Add(ValueObject.new(nil, t.optional(t.Instance)))
	self._soundGroup = self._maid:Add(ValueObject.new(nil, t.optional(t.Instance)))
	self._bpm = self._maid:Add(ValueObject.new(nil, t.optional(t.number)))
	self._defaultCrossFadeTime = self._maid:Add(ValueObject.new(0.5, "number"))
	self._volumeMultiplier = self._maid:Add(ValueObject.new(1, "number"))

	self._layers = {}

	if soundParent then
		self:SetSoundParent(soundParent)
	end

	return self
end

function LayeredLoopedSoundPlayer:SetDefaultCrossFadeTime(crossFadeTime: ValueObject.Mountable<number>)
	return self._defaultCrossFadeTime:Mount(crossFadeTime)
end

function LayeredLoopedSoundPlayer:SetVolumeMultiplier(volumeMultiplier: ValueObject.Mountable<number>)
	return self._volumeMultiplier:Mount(volumeMultiplier)
end

function LayeredLoopedSoundPlayer:SetBPM(bpm: ValueObject.Mountable<number?>)
	self._bpm.Value = bpm
end

function LayeredLoopedSoundPlayer:SetSoundParent(soundParent: Instance?)
	assert(typeof(soundParent) == "Instance" or soundParent == nil, "Bad soundParent")

	self._soundParent.Value = soundParent
end

function LayeredLoopedSoundPlayer:SetSoundGroup(soundGroup: SoundGroup?)
	return self._soundGroup:Mount(soundGroup)
end

function LayeredLoopedSoundPlayer:Swap(layerId: string, soundId, scheduleOptions)
	assert(type(layerId) == "string", "Bad layerId")
	assert(SoundUtils.isConvertableToRbxAsset(soundId) or soundId == nil, "Bad soundId")
	assert(SoundLoopScheduleUtils.isLoopedSchedule(scheduleOptions) or scheduleOptions == nil, "Bad scheduleOptions")

	local layer = self:_getOrCreateLayer(layerId)
	layer:Swap(soundId, scheduleOptions)
end

function LayeredLoopedSoundPlayer:SwapOnLoop(layerId, soundId, scheduleOptions)
	assert(type(layerId) == "string", "Bad layerId")
	assert(SoundUtils.isConvertableToRbxAsset(soundId) or soundId == nil, "Bad soundId")

	local layer = self:_getOrCreateLayer(layerId)
	layer:SwapOnLoop(soundId, scheduleOptions)
end

function LayeredLoopedSoundPlayer:SwapToSamples(layerId, soundId, scheduleOptions)
	assert(type(layerId) == "string", "Bad layerId")
	assert(SoundUtils.isConvertableToRbxAsset(soundId) or soundId == nil, "Bad soundId")
	assert(SoundLoopScheduleUtils.isLoopedSchedule(scheduleOptions) or scheduleOptions == nil, "Bad scheduleOptions")

	local layer = self:_getOrCreateLayer(layerId)
	layer:SwapToSamples(soundId, scheduleOptions)
end

function LayeredLoopedSoundPlayer:SwapToChoice(layerId, soundIdList, scheduleOptions)
	assert(type(layerId) == "string", "Bad layerId")
	assert(type(soundIdList) == "table", "Bad soundIdList")
	assert(SoundLoopScheduleUtils.isLoopedSchedule(scheduleOptions) or scheduleOptions == nil, "Bad scheduleOptions")

	local layer = self:_getOrCreateLayer(layerId)
	layer:SwapToChoice(soundIdList, scheduleOptions)
end

function LayeredLoopedSoundPlayer:PlayOnce(layerId, soundIdList, scheduleOptions)
	assert(type(layerId) == "string", "Bad layerId")
	assert(type(soundIdList) == "table", "Bad soundIdList")
	assert(SoundLoopScheduleUtils.isLoopedSchedule(scheduleOptions) or scheduleOptions == nil, "Bad scheduleOptions")

	local layer = self:_getOrCreateLayer(layerId)
	layer:PlayOnce(soundIdList, scheduleOptions)
end

function LayeredLoopedSoundPlayer:PlayOnceOnLoop(layerId, soundId, scheduleOptions)
	assert(type(layerId) == "string", "Bad layerId")

	local layer = self:_getOrCreateLayer(layerId)
	layer:PlayOnceOnLoop(soundId, scheduleOptions)
end

function LayeredLoopedSoundPlayer:_getOrCreateLayer(layerId)
	if self._layers[layerId] then
		return self._layers[layerId]
	end

	local maid = Maid.new()

	local layer = maid:Add(LoopedSoundPlayer.new())
	layer:SetDoSyncSoundPlayback(true)

	maid:GiveTask(self._soundGroup:Observe():Subscribe(function(soundGroup)
		layer:SetSoundGroup(soundGroup)
	end))

	maid:GiveTask(layer:SetCrossFadeTime(self._defaultCrossFadeTime:Observe()))

	maid:GiveTask(self._bpm:Observe():Subscribe(function(bpm)
		layer:SetBPM(bpm)
	end))

	maid:GiveTask(self:ObserveVisible():Subscribe(function(isVisible, doNotAnimate)
		layer:SetVisible(isVisible, doNotAnimate)
	end))

	maid:GiveTask(self._soundParent:Observe():Subscribe(function(parent)
		layer:SetSoundParent(parent)
	end))

	maid:GiveTask(Rx.combineLatest({
		visible = self:ObserveRenderStepped(),
		multiplier = self._volumeMultiplier:Observe(),
	}):Subscribe(function(state)
		layer:SetVolumeMultiplier(state.multiplier * state.visible)
	end))

	self._layers[layerId] = layer
	maid:GiveTask(function()
		if self._layers[layerId] == layer then
			self._layers[layerId] = nil
		end
	end)

	self._layerMaid[layerId] = maid

	return layer
end

function LayeredLoopedSoundPlayer:StopLayer(layerId: string)
	assert(type(layerId) == "string", "Bad layerId")

	self._layerMaid[layerId] = nil
end

function LayeredLoopedSoundPlayer:StopAll()
	self._layerMaid:DoCleaning()
end

return LayeredLoopedSoundPlayer
