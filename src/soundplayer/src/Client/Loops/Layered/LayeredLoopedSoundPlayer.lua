--!strict
--[=[
	This class provides layered synchronized sound playback with looping and scheduling, which is useful for
	implementing complex ambient soundscapes or music tracks that require multiple layers to be played in sync, for example,
	constructed music that adapts to game states.

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
local t: any = require("t")

local LayeredLoopedSoundPlayer = setmetatable({}, SpringTransitionModel)
LayeredLoopedSoundPlayer.ClassName = "LayeredLoopedSoundPlayer"
LayeredLoopedSoundPlayer.__index = LayeredLoopedSoundPlayer

export type LayeredLoopedSoundPlayer =
	typeof(setmetatable(
		{} :: {
			_layerMaid: Maid.Maid,
			_soundParent: ValueObject.ValueObject<Instance?>,
			_soundGroup: ValueObject.ValueObject<SoundGroup?>,
			_bpm: ValueObject.ValueObject<number?>,
			_defaultCrossFadeTime: ValueObject.ValueObject<number>,
			_volumeMultiplier: ValueObject.ValueObject<number>,
			_layers: { [string]: LoopedSoundPlayer.LoopedSoundPlayer },
		},
		{} :: typeof({ __index = LayeredLoopedSoundPlayer })
	))
	& SpringTransitionModel.SpringTransitionModel<number>

--[=[
	Constructs a new LayeredLoopedSoundPlayer.

	@param soundParent Instance? -- Optional parent for sounds
	@return LayeredLoopedSoundPlayer
]=]
function LayeredLoopedSoundPlayer.new(soundParent: Instance?): LayeredLoopedSoundPlayer
	local self: LayeredLoopedSoundPlayer = setmetatable(SpringTransitionModel.new() :: any, LayeredLoopedSoundPlayer)

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

--[=[
	Sets the default cross fade time for the LayeredLoopedSoundPlayer.
]=]
function LayeredLoopedSoundPlayer.SetDefaultCrossFadeTime(
	self: LayeredLoopedSoundPlayer,
	crossFadeTime: ValueObject.Mountable<number>
): () -> ()
	return self._defaultCrossFadeTime:Mount(crossFadeTime)
end

--[=[
	Sets the volume multiplier for the LayeredLoopedSoundPlayer.
]=]
function LayeredLoopedSoundPlayer.SetVolumeMultiplier(
	self: LayeredLoopedSoundPlayer,
	volumeMultiplier: ValueObject.Mountable<number>
): () -> ()
	return self._volumeMultiplier:Mount(volumeMultiplier)
end

--[=[
	Sets the BPM for syncing sound playback.
]=]
function LayeredLoopedSoundPlayer.SetBPM(self: LayeredLoopedSoundPlayer, bpm: ValueObject.Mountable<number?>): () -> ()
	return self._bpm:Mount(bpm)
end

--[=[
	Sets the parent instance for the LayeredLoopedSoundPlayer.
]=]
function LayeredLoopedSoundPlayer.SetSoundParent(self: LayeredLoopedSoundPlayer, soundParent: Instance?): ()
	assert(typeof(soundParent) == "Instance" or soundParent == nil, "Bad soundParent")

	self._soundParent.Value = soundParent
end

--[=[
	Sets the sound group for the LayeredLoopedSoundPlayer.
]=]
function LayeredLoopedSoundPlayer.SetSoundGroup(
	self: LayeredLoopedSoundPlayer,
	soundGroup: ValueObject.Mountable<SoundGroup?>
): () -> ()
	return self._soundGroup:Mount(soundGroup)
end

--[=[
	Swaps the layer to play the given sound on loop schedule.
]=]
function LayeredLoopedSoundPlayer.Swap(
	self: LayeredLoopedSoundPlayer,
	layerId: string,
	soundId: SoundUtils.SoundId,
	scheduleOptions: SoundLoopScheduleUtils.SoundLoopSchedule?
): ()
	assert(type(layerId) == "string", "Bad layerId")
	assert(SoundUtils.isConvertableToRbxAsset(soundId) or soundId == nil, "Bad soundId")
	assert(SoundLoopScheduleUtils.isLoopedSchedule(scheduleOptions) or scheduleOptions == nil, "Bad scheduleOptions")

	local layer = self:_getOrCreateLayer(layerId)
	layer:Swap(soundId, scheduleOptions)
end

--[=[
	Swaps the layer to play on the next loop.
]=]
function LayeredLoopedSoundPlayer.SwapOnLoop(
	self: LayeredLoopedSoundPlayer,
	layerId: string,
	soundId: SoundUtils.SoundId,
	scheduleOptions: SoundLoopScheduleUtils.SoundLoopSchedule?
): ()
	assert(type(layerId) == "string", "Bad layerId")
	assert(SoundUtils.isConvertableToRbxAsset(soundId) or soundId == nil, "Bad soundId")

	local layer = self:_getOrCreateLayer(layerId)
	layer:SwapOnLoop(soundId, scheduleOptions)
end

--[=[
	Swaps the layer to play from a list of samples.
]=]
function LayeredLoopedSoundPlayer.SwapToSamples(
	self: LayeredLoopedSoundPlayer,
	layerId: string,
	soundIdList: { SoundUtils.SoundId },
	scheduleOptions: SoundLoopScheduleUtils.SoundLoopSchedule?
): ()
	assert(type(layerId) == "string", "Bad layerId")
	assert(type(soundIdList) == "table", "Bad soundIdList")
	assert(SoundLoopScheduleUtils.isLoopedSchedule(scheduleOptions) or scheduleOptions == nil, "Bad scheduleOptions")

	local layer = self:_getOrCreateLayer(layerId)
	layer:SwapToSamples(soundIdList, scheduleOptions)
end

--[=[
	Swaps the layer to play a random choice from a list of samples.
]=]
function LayeredLoopedSoundPlayer.SwapToChoice(
	self: LayeredLoopedSoundPlayer,
	layerId: string,
	soundIdList: { SoundUtils.SoundId },
	scheduleOptions: SoundLoopScheduleUtils.SoundLoopSchedule?
): ()
	assert(type(layerId) == "string", "Bad layerId")
	assert(type(soundIdList) == "table", "Bad soundIdList")
	assert(SoundLoopScheduleUtils.isLoopedSchedule(scheduleOptions) or scheduleOptions == nil, "Bad scheduleOptions")

	local layer = self:_getOrCreateLayer(layerId)
	layer:SwapToChoice(soundIdList, scheduleOptions)
end

--[=[
	Plays the given sound once on the layer.
]=]
function LayeredLoopedSoundPlayer.PlayOnce(
	self: LayeredLoopedSoundPlayer,
	layerId: string,
	soundId: SoundUtils.SoundId,
	scheduleOptions: SoundLoopScheduleUtils.SoundLoopSchedule?
): ()
	assert(type(layerId) == "string", "Bad layerId")
	assert(SoundLoopScheduleUtils.isLoopedSchedule(scheduleOptions) or scheduleOptions == nil, "Bad scheduleOptions")

	local layer = self:_getOrCreateLayer(layerId)
	layer:PlayOnce(soundId, scheduleOptions)
end

--[=[
	Plays the given sound once on the next loop of the layer.
]=]
function LayeredLoopedSoundPlayer.PlayOnceOnLoop(
	self: LayeredLoopedSoundPlayer,
	layerId: string,
	soundId: SoundUtils.SoundId,
	scheduleOptions: SoundLoopScheduleUtils.SoundLoopSchedule?
): ()
	assert(type(layerId) == "string", "Bad layerId")

	local layer = self:_getOrCreateLayer(layerId)
	layer:PlayOnceOnLoop(soundId, scheduleOptions)
end

function LayeredLoopedSoundPlayer._getOrCreateLayer(
	self: LayeredLoopedSoundPlayer,
	layerId: string
): LoopedSoundPlayer.LoopedSoundPlayer
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
	}):Subscribe(function(state: any)
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

--[=[
	Stops playback on the given layer.
]=]
function LayeredLoopedSoundPlayer.StopLayer(self: LayeredLoopedSoundPlayer, layerId: string): ()
	assert(type(layerId) == "string", "Bad layerId")

	self._layerMaid[layerId] = nil
end

function LayeredLoopedSoundPlayer.StopAll(self: LayeredLoopedSoundPlayer): ()
	self._layerMaid:DoCleaning()
end

return LayeredLoopedSoundPlayer
