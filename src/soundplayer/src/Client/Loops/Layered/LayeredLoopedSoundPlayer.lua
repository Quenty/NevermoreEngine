--!strict
--[=[
	This class provides layered synchronized sound playback with looping and scheduling, which is useful for
	implementing complex ambient soundscapes or music tracks that require multiple layers to be played in sync, for example,
	constructed music that adapts to game states.

	@class LayeredLoopedSoundPlayer
]=]

local require = require(script.Parent.loader).load(script)

local LayeredSoundHelper = require("LayeredSoundHelper")
local LoopedSoundPlayer = require("LoopedSoundPlayer")
local Maid = require("Maid")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
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
			_defaultSoundParent: ValueObject.ValueObject<Instance?>,
			_defaultSoundGroup: ValueObject.ValueObject<SoundGroup?>,
			_defaultBPM: ValueObject.ValueObject<number?>,
			_defaultCrossFadeTime: ValueObject.ValueObject<number>,
			_volumeMultiplier: ValueObject.ValueObject<number>,

			_layeredSoundHelper: LayeredSoundHelper.LayeredSoundHelper<LoopedSoundPlayer.LoopedSoundPlayer>,
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

	self._defaultSoundParent = self._maid:Add(ValueObject.new(nil, t.optional(t.Instance)))
	self._defaultSoundGroup = self._maid:Add(ValueObject.new(nil, t.optional(t.Instance)))
	self._defaultBPM = self._maid:Add(ValueObject.new(nil, t.optional(t.number)))
	self._defaultCrossFadeTime = self._maid:Add(ValueObject.new(0.5, "number"))
	self._volumeMultiplier = self._maid:Add(ValueObject.new(1, "number"))

	self._layeredSoundHelper = self._maid:Add(LayeredSoundHelper.new(function(maid): any
		local layer = maid:Add(LoopedSoundPlayer.new())
		self:_handleNewLayer(maid, layer)
		return layer
	end))

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
	return self._defaultBPM:Mount(bpm)
end

--[=[
	Sets the parent instance for the LayeredLoopedSoundPlayer.
]=]
function LayeredLoopedSoundPlayer.SetSoundParent(self: LayeredLoopedSoundPlayer, soundParent: Instance?): ()
	assert(typeof(soundParent) == "Instance" or soundParent == nil, "Bad soundParent")

	self._defaultSoundParent.Value = soundParent
end

--[=[
	Sets the sound group for the LayeredLoopedSoundPlayer.
]=]
function LayeredLoopedSoundPlayer.SetSoundGroup(
	self: LayeredLoopedSoundPlayer,
	soundGroup: ValueObject.Mountable<SoundGroup?>
): () -> ()
	return self._defaultSoundGroup:Mount(soundGroup)
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

	local layer = self._layeredSoundHelper:GetOrCreateLayer(layerId)
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

	local layer = self._layeredSoundHelper:GetOrCreateLayer(layerId)
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

	local layer = self._layeredSoundHelper:GetOrCreateLayer(layerId)
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

	local layer = self._layeredSoundHelper:GetOrCreateLayer(layerId)
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

	local layer = self._layeredSoundHelper:GetOrCreateLayer(layerId)
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

	local layer = self._layeredSoundHelper:GetOrCreateLayer(layerId)
	layer:PlayOnceOnLoop(soundId, scheduleOptions)
end

function LayeredLoopedSoundPlayer._handleNewLayer(
	self: LayeredLoopedSoundPlayer,
	maid: Maid.Maid,
	layer: LoopedSoundPlayer.LoopedSoundPlayer
): ()
	layer:SetDoSyncSoundPlayback(true)
	maid:GiveTask(layer:SetSoundGroup(self._defaultSoundGroup:Observe()))
	maid:GiveTask(layer:SetCrossFadeTime(self._defaultCrossFadeTime:Observe()))
	maid:GiveTask(layer:SetBPM(self._defaultBPM:Observe()))
	maid:GiveTask(layer:SetSoundParent(self._defaultSoundParent:Observe()))

	maid:GiveTask(self:ObserveVisible():Subscribe(function(isVisible, doNotAnimate)
		layer:SetVisible(isVisible, doNotAnimate)
	end))

	maid:GiveTask(Rx.combineLatest({
		visible = self:ObserveRenderStepped(),
		multiplier = self._volumeMultiplier:Observe(),
	}):Subscribe(function(state: any)
		layer:SetVolumeMultiplier(state.multiplier * state.visible)
	end))

	return layer
end

--[=[
	Stops playback on the given layer.
]=]
function LayeredLoopedSoundPlayer.StopLayer(
	self: LayeredLoopedSoundPlayer,
	layerId: string,
	doNotAnimate: boolean?
): Promise.Promise<()>
	assert(type(layerId) == "string", "Bad layerId")

	local found = self._layeredSoundHelper:FindLayer(layerId)
	if not found then
		return Promise.resolved()
	end

	return found:PromiseHide(doNotAnimate)
end

function LayeredLoopedSoundPlayer.StopAll(self: LayeredLoopedSoundPlayer, doNotAnimate: boolean?): ()
	local promises: { Promise.Promise<()> } = {}
	for _, layer: any in self._layeredSoundHelper:GetAllLayers() do
		table.insert(promises, layer:PromiseHide(doNotAnimate))
	end
	return PromiseUtils.all(promises)
end

return LayeredLoopedSoundPlayer
