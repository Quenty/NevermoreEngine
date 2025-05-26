--!strict
--[=[
	@class LoopedSoundPlayer
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local Maid = require("Maid")
local Promise = require("Promise")
local PromiseMaidUtils = require("PromiseMaidUtils")
local RandomSampler = require("RandomSampler")
local RandomUtils = require("RandomUtils")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local Signal = require("Signal")
local SimpleLoopedSoundPlayer = require("SimpleLoopedSoundPlayer")
local SoundLoopScheduleUtils = require("SoundLoopScheduleUtils")
local SoundPromiseUtils = require("SoundPromiseUtils")
local SoundUtils = require("SoundUtils")
local SpringTransitionModel = require("SpringTransitionModel")
local ValueObject = require("ValueObject")

local LoopedSoundPlayer = setmetatable({}, SpringTransitionModel)
LoopedSoundPlayer.ClassName = "LoopedSoundPlayer"
LoopedSoundPlayer.__index = LoopedSoundPlayer

export type LoopedSoundPlayer = typeof(setmetatable(
	{} :: {
		_currentSoundLooped: Signal.Signal<()>,
		_currentSoundLoopedAfterDelay: Signal.Signal<()>,
		_bpm: ValueObject.ValueObject<number?>,
		_soundParent: ValueObject.ValueObject<Instance?>,
		_soundGroup: ValueObject.ValueObject<SoundGroup?>,
		_crossFadeTime: ValueObject.ValueObject<number>,
		_volumeMultiplier: ValueObject.ValueObject<number>,
		_doSyncSoundPlayback: ValueObject.ValueObject<boolean>,
		_currentActiveSound: ValueObject.ValueObject<Sound?>,
		_currentSoundId: ValueObject.ValueObject<(string | number)?>,
		_defaultScheduleOptions: SoundLoopScheduleUtils.SoundLoopSchedule,
		_currentLoopSchedule: ValueObject.ValueObject<SoundLoopScheduleUtils.SoundLoopSchedule>,
	},
	{} :: typeof({ __index = LoopedSoundPlayer })
)) & SpringTransitionModel.SpringTransitionModel<number>

function LoopedSoundPlayer.new(soundId: (string | number)?, soundParent: Instance?)
	assert(soundId == nil or SoundUtils.isConvertableToRbxAsset(soundId), "Bad soundId")

	local self: LoopedSoundPlayer = setmetatable(SpringTransitionModel.new() :: any, LoopedSoundPlayer)

	self._currentSoundLooped = self._maid:Add(Signal.new() :: any)
	self._currentSoundLoopedAfterDelay = self._maid:Add(Signal.new() :: any)

	self:SetSpeed(10)

	self._bpm = self._maid:Add(ValueObject.new(nil))
	self._soundParent = self._maid:Add(ValueObject.new(nil))
	self._soundGroup = self._maid:Add(ValueObject.new(nil))
	self._crossFadeTime = self._maid:Add(ValueObject.new(0.5, "number"))
	self._volumeMultiplier = self._maid:Add(ValueObject.new(1, "number"))
	self._doSyncSoundPlayback = self._maid:Add(ValueObject.new(false, "boolean"))
	self._currentActiveSound = self._maid:Add(ValueObject.new(nil))
	self._currentSoundId = self._maid:Add(ValueObject.new(soundId))

	self._defaultScheduleOptions = SoundLoopScheduleUtils.default()
	self._currentLoopSchedule = self._maid:Add(ValueObject.new(self._defaultScheduleOptions))

	if soundParent then
		self:SetSoundParent(soundParent)
	end

	if soundId then
		self:Swap(soundId)
	end

	self:_setupRender()

	return self
end

function LoopedSoundPlayer.SetCrossFadeTime(self: LoopedSoundPlayer, crossFadeTime: number)
	return self._crossFadeTime:Mount(crossFadeTime)
end

function LoopedSoundPlayer.SetVolumeMultiplier(self: LoopedSoundPlayer, volume: number)
	self._volumeMultiplier.Value = volume
end

function LoopedSoundPlayer.SetSoundGroup(self: LoopedSoundPlayer, soundGroup: SoundGroup?)
	return self._soundGroup:Mount(soundGroup)
end

function LoopedSoundPlayer.SetBPM(self: LoopedSoundPlayer, bpm: number?)
	assert(type(bpm) == "number" or bpm == nil, "Bad bpm")

	self._bpm.Value = bpm
end

function LoopedSoundPlayer.SetSoundParent(self: LoopedSoundPlayer, parent: Instance?)
	self._soundParent.Value = parent
end

function LoopedSoundPlayer.Swap(self: LoopedSoundPlayer, soundId, loopSchedule)
	assert(SoundUtils.isConvertableToRbxAsset(soundId) or soundId == nil, "Bad soundId")
	loopSchedule = self:_convertToLoopedSchedule(loopSchedule)

	local maid = Maid.new()

	maid:GiveTask(self:_scheduleFirstPlay(loopSchedule, function()
		self._currentLoopSchedule.Value = loopSchedule
		self._currentSoundId.Value = soundId
	end))

	self._maid._swappingTo = maid
end

function LoopedSoundPlayer.SetDoSyncSoundPlayback(self: LoopedSoundPlayer, doSyncSoundPlayback: boolean)
	self._doSyncSoundPlayback.Value = doSyncSoundPlayback
end

function LoopedSoundPlayer._setupRender(self: LoopedSoundPlayer)
	self._maid:GiveTask(self._currentSoundId
		:ObserveBrio(function(value)
			return value ~= nil
		end)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid = brio:ToMaid()
			local soundId = brio:GetValue()

			maid:GiveTask(self:_renderSoundPlayer(soundId))
		end))
end

function LoopedSoundPlayer._renderSoundPlayer(self: LoopedSoundPlayer, soundId)
	local maid = Maid.new()

	local renderMaid = Maid.new()
	local soundPlayer = renderMaid:Add(SimpleLoopedSoundPlayer.new(soundId))
	soundPlayer:SetTransitionTime(self._crossFadeTime)

	renderMaid:GiveTask(self._soundGroup:Observe():Subscribe(function(soundGroup)
		soundPlayer:SetSoundGroup(soundGroup)
	end))

	renderMaid:GiveTask(Rx.combineLatest({
		bpm = self._bpm:Observe(),
		isLoaded = Rx.fromPromise(SoundPromiseUtils.promiseLoaded(soundPlayer.Sound)),
		doSyncSoundPlayback = self._doSyncSoundPlayback:Observe(),
		timeLength = RxInstanceUtils.observeProperty(soundPlayer.Sound, "TimeLength"),
	}):Subscribe(function(state: any)
		local syncMaid = Maid.new()

		if state.doSyncSoundPlayback then
			if state.bpm then
				local bps = state.bpm / 60
				local beatTime = 1 / bps
				local truncatedTimeLength = math.floor(state.timeLength / beatTime) * beatTime
				local currentTimePosition = soundPlayer.Sound.TimePosition
				local clockDistanceIntoBeat = os.clock() % beatTime
				local soundDistanceIntoBeat = currentTimePosition % beatTime

				-- Skip to next beat
				local offset = (beatTime + (clockDistanceIntoBeat - soundDistanceIntoBeat)) % beatTime
				soundPlayer.Sound.TimePosition = currentTimePosition + offset

				syncMaid:GiveTask(RunService.RenderStepped:Connect(function()
					if soundPlayer.Sound.TimePosition > truncatedTimeLength then
						soundPlayer.Sound.TimePosition = soundPlayer.Sound.TimePosition % truncatedTimeLength

						if self.Destroy then
							if self._currentActiveSound.Value == soundPlayer.Sound then
								self._currentSoundLooped:Fire()
							end
						end
					end
				end))
			else
				soundPlayer.Sound.TimePosition = os.clock() % state.timeLength
			end
		end

		renderMaid._syncing = syncMaid
	end))

	maid:GiveTask(Rx.combineLatestDefer({
		loopSchedule = self._currentLoopSchedule:Observe(),
	}):Subscribe(function(state)
		local scheduleMaid = Maid.new()

		scheduleMaid:GiveTask(self:_setupLoopScheduling(soundPlayer, state.loopSchedule))

		renderMaid._loopMaid = scheduleMaid
	end))

	maid:GiveTask(soundPlayer.Sound.DidLoop:Connect(function()
		self._currentSoundLooped:Fire()
	end))

	self._currentActiveSound.Value = soundPlayer.Sound

	maid:GiveTask(function()
		if self._currentActiveSound.Value == soundPlayer.Sound then
			self._currentActiveSound.Value = nil
		end
	end)

	renderMaid:GiveTask(self._soundParent:Observe():Subscribe(function(parent)
		soundPlayer.Sound.Parent = parent
	end))

	maid:GiveTask(Rx.combineLatest({
		visible = self:ObserveRenderStepped(),
		multiplier = self._volumeMultiplier:Observe(),
	}):Subscribe(function(state: any)
		soundPlayer:SetVolumeMultiplier(state.multiplier * state.visible)
	end))

	maid:GiveTask(self:ObserveVisible():Subscribe(function(isVisible, doNotAnimate)
		soundPlayer:SetVisible(isVisible, doNotAnimate)
	end))

	maid:GiveTask(function()
		soundPlayer:PromiseHide():Then(function()
			renderMaid:Destroy()
		end)
	end)

	return maid
end

function LoopedSoundPlayer._setupLoopScheduling(self: LoopedSoundPlayer, soundPlayer, loopSchedule)
	local maid = Maid.new()

	if loopSchedule.maxLoops then
		local loopCount = 0
		maid:GiveTask(self._currentSoundLooped:Connect(function()
			loopCount = loopCount + 1

			-- Cancel
			if loopCount > loopSchedule.maxLoops then
				self._currentSoundId.Value = nil
			end
		end))
	end

	if loopSchedule.loopDelay then
		maid:GiveTask(self._currentSoundLooped:Connect(function()
			local waitTime = SoundLoopScheduleUtils.getWaitTimeSeconds(loopSchedule.loopDelay)

			soundPlayer.Sound:Pause()

			maid._scheduled = task.delay(waitTime, function()
				self._currentSoundLoopedAfterDelay:Fire()
				soundPlayer.Sound:Play()
			end)
		end))
	else
		maid:GiveTask(self._currentSoundLooped:Connect(function()
			self._currentSoundLoopedAfterDelay:Fire()
		end))
	end

	return maid
end

function LoopedSoundPlayer.SwapToSamples(self: LoopedSoundPlayer, soundIdList, loopSchedule)
	assert(type(soundIdList) == "table", "Bad soundIdList")
	loopSchedule = self:_convertToLoopedSchedule(loopSchedule)

	local loopMaid = Maid.new()

	loopMaid:GiveTask(self:_scheduleFirstPlay(loopSchedule, function()
		local sampler = RandomSampler.new(soundIdList)
		self._currentLoopSchedule.Value = loopSchedule
		self._currentSoundId.Value = sampler:Sample()

		loopMaid:GiveTask(self._currentSoundLoopedAfterDelay:Connect(function()
			self._currentSoundId.Value = sampler:Sample()
		end))
	end))

	self._maid._swappingTo = loopMaid
end

function LoopedSoundPlayer.SwapToChoice(self: LoopedSoundPlayer, soundIdList, loopSchedule)
	assert(type(soundIdList) == "table", "Bad soundIdList")
	loopSchedule = self:_convertToLoopedSchedule(loopSchedule)

	local loopMaid = Maid.new()

	loopMaid:GiveTask(self:_scheduleFirstPlay(loopSchedule, function()
		self._currentLoopSchedule.Value = loopSchedule
		self._currentSoundId.Value = RandomUtils.choice(soundIdList)

		loopMaid:GiveTask(self._currentSoundLoopedAfterDelay:Connect(function()
			self._currentSoundId.Value = RandomUtils.choice(soundIdList)
		end))
	end))

	self._maid._swappingTo = loopMaid
end

function LoopedSoundPlayer.PlayOnce(self: LoopedSoundPlayer, soundId, loopSchedule)
	assert(SoundUtils.isConvertableToRbxAsset(soundId) or soundId == nil, "Bad soundId")
	loopSchedule = self:_convertToLoopedSchedule(loopSchedule)

	self:Swap(soundId, SoundLoopScheduleUtils.maxLoops(1, loopSchedule))
end

function LoopedSoundPlayer.SwapOnLoop(self: LoopedSoundPlayer, soundId, loopSchedule)
	assert(SoundUtils.isConvertableToRbxAsset(soundId) or soundId == nil, "Bad soundId")
	loopSchedule = self:_convertToLoopedSchedule(loopSchedule)

	self:Swap(soundId, SoundLoopScheduleUtils.onNextLoop(loopSchedule))
end

function LoopedSoundPlayer.PlayOnceOnLoop(self: LoopedSoundPlayer, soundId, loopSchedule)
	assert(SoundUtils.isConvertableToRbxAsset(soundId) or soundId == nil, "Bad soundId")
	loopSchedule = self:_convertToLoopedSchedule(loopSchedule)

	self:PlayOnce(soundId, SoundLoopScheduleUtils.onNextLoop(loopSchedule))
end

function LoopedSoundPlayer._convertToLoopedSchedule(self: LoopedSoundPlayer, loopSchedule)
	assert(SoundLoopScheduleUtils.isLoopedSchedule(loopSchedule) or loopSchedule == nil, "Bad loopSchedule")
	return loopSchedule or self._defaultScheduleOptions
end

function LoopedSoundPlayer._scheduleFirstPlay(self: LoopedSoundPlayer, loopSchedule, callback)
	assert(SoundLoopScheduleUtils.isLoopedSchedule(loopSchedule), "Bad loopSchedule")
	assert(type(callback) == "function", "Bad callback")

	local maid = Maid.new()

	local observable: any = Rx.of(true)
	if loopSchedule.playOnNextLoop then
		observable = observable:Pipe({
			Rx.switchMap(function()
				local waitTime = nil
				if loopSchedule.maxInitialWaitTimeForNextLoop then
					waitTime = SoundLoopScheduleUtils.getWaitTimeSeconds(loopSchedule.maxInitialWaitTimeForNextLoop)
				end

				return self:_observeActiveSoundFinishLoop(waitTime)
			end) :: any,
		})
	end

	if loopSchedule.initialDelay then
		observable = observable:Pipe({
			Rx.switchMap(function()
				return Rx.delayed(SoundLoopScheduleUtils.getWaitTimeSeconds(loopSchedule.initialDelay)) :: any
			end) :: any,
		})
	end

	-- Immediate
	if observable then
		maid._observeOnce = observable:Subscribe(function()
			maid._observeOnce = nil
			callback()
		end)
	else
		callback()
	end

	return maid
end

function LoopedSoundPlayer.StopAfterLoop(self: LoopedSoundPlayer)
	local swapMaid = Maid.new()

	swapMaid:GiveTask(self._currentSoundLooped:Connect(function()
		if self._maid._swappingTo == swapMaid then
			self._currentSoundId.Value = nil
		end
	end))

	self._maid._swappingTo = swapMaid
end

function LoopedSoundPlayer._observeActiveSoundFinishLoop(self: LoopedSoundPlayer, maxWaitTime)
	local startTime = os.clock()

	return self._currentActiveSound:Observe():Pipe({
		Rx.throttleDefer() :: any,
		Rx.switchMap(function(sound): any
			if not sound then
				return Rx.of(true)
			end

			return Rx.combineLatest({
				timeLength = RxInstanceUtils.observeProperty(sound, "TimeLength"),
				timePosition = RxInstanceUtils.observeProperty(sound, "TimePosition"),
				crossFadeTime = self._crossFadeTime:Observe(),
			}):Pipe({
				Rx.switchMap(function(state: any): any
					local timeElapsed = os.clock() - startTime
					local timeRemaining
					if maxWaitTime then
						timeRemaining = maxWaitTime - timeElapsed
					end

					-- We assume it's gonna load
					if state.timeLength == 0 then
						if timeRemaining then
							return Rx.delayed(timeRemaining)
						else
							return Rx.EMPTY
						end
					end

					local waitTime = state.timeLength - state.timePosition - state.crossFadeTime

					if timeRemaining then
						waitTime = math.min(waitTime, timeRemaining)
					end

					return Rx.delayed(waitTime)
				end) :: any,
			})
		end) :: any,
	}) :: any
end

function LoopedSoundPlayer.PromiseLoopDone(self: LoopedSoundPlayer): Promise.Promise<()>
	local promise = self._maid:GivePromise(Promise.new())

	PromiseMaidUtils.whilePromise(promise, function(maid)
		maid:GiveTask(self._currentSoundLooped:Connect(function()
			promise:Resolve()
		end))
	end)

	return promise
end

function LoopedSoundPlayer.PromiseSustain(_self: LoopedSoundPlayer): Promise.Promise<()>
	-- Never resolve (?)
	return Promise.new()
end

function LoopedSoundPlayer.GetSound(self: LoopedSoundPlayer): Sound?
	return self._currentActiveSound.Value
end

return LoopedSoundPlayer
