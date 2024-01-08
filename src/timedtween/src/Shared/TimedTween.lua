--[=[
	Tween that is a specific time, useful for countdowns and other things

	@class TimedTween
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BasicPane = require("BasicPane")
local ValueObject = require("ValueObject")
local Math = require("Math")
local StepUtils = require("StepUtils")
local Observable = require("Observable")
local Maid = require("Maid")
local Promise = require("Promise")

local TimedTween = setmetatable({}, BasicPane)
TimedTween.ClassName = "TimedTween"
TimedTween.__index = TimedTween

--[=[
	Timed transition module

	@param transitionTime number? -- Optional
	@return TimedTween
]=]
function TimedTween.new(transitionTime)
	local self = setmetatable(BasicPane.new(), TimedTween)

	self._transitionTime = self._maid:Add(ValueObject.new(0.15, "number"))
	self._state = self._maid:Add(ValueObject.new({
		p0 = 0;
		p1 = 0;
		t0 = 0;
		t1 = 0;
	}))

	if transitionTime then
		self:SetTransitionTime(transitionTime)
	end

	self._maid:GiveTask(self._transitionTime.Changed:Connect(function()
		self:_updateState()
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(_, doNotAnimate)
		self:_updateState(doNotAnimate)
	end))
	self:_updateState()

	return self
end

--[=[
	Sets the transition time

	@param transitionTime number | Observable<number>
	@return MaidTask
]=]
function TimedTween:SetTransitionTime(transitionTime)
	return self._transitionTime:Mount(transitionTime)
end

--[=[
	Gets the transition time

	@return number
]=]
function TimedTween:GetTransitionTime()
	return self._transitionTime.Value
end

--[=[
	Observes the transition time

	@return Observable<number>
]=]
function TimedTween:ObserveTransitionTime()
	return self._transitionTime:Observe()
end

--[=[
	Observes how far into the transition we are, from 0 to 1

	@return Observable<number>
]=]
function TimedTween:ObserveRenderStepped()
	return self:ObserveOnSignal(RunService.RenderStepped)
end

--[=[
	Observes the transition on a specific signal

	@param signal Signal
	@return Observable<number>
]=]
function TimedTween:ObserveOnSignal(signal)
	return Observable.new(function(sub)
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
			local state = self:_computeState(os.clock())
			sub:Fire(state.p)
			return state.rtime > 0
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(self._state.Changed:Connect(startAnimate))
		startAnimate()

		return maid
	end)
end

--[=[
	Observes the transition

	@return Observable<number>
]=]
function TimedTween:Observe()
	return self:ObserveOnSignal(RunService.RenderStepped)
end

--[=[
	Promises when the tween is finished

	@return Promise
]=]
function TimedTween:PromiseFinished()
	local initState = self:_computeState(os.clock())
	if initState.rtime <=  0 then
		return Promise.resolved()
	end

	local maid = Maid.new()
	local promise = Promise.new()
	maid:GiveTask(promise)

	maid:GiveTask(self._state:Observe():Subscribe(function()
		local state = self:_computeState(os.clock())
		if state.rtime <= 0 then
			promise:Resolve()
			return
		end

		maid._scheduled = task.delay(state.rtime, function()
			promise:Resolve()
		end)
	end))

	self._maid[promise] = maid

	promise:Finally(function()
		self._maid[promise] = nil
	end)

	maid:GiveTask(function()
		self._maid[promise] = nil
	end)
	return promise
end

function TimedTween:_updateState(doNotAnimate)
	local transitionTime = self._transitionTime.Value
	local target = self:IsVisible() and 1 or 0;

	local now = os.clock()
	local computed = self:_computeState(now)
	local p0 = computed.p

	local remainingDist = target - p0
	if doNotAnimate then
		self._state.Value = {
			p0 = target;
			p1 = target;
			t0 = now;
			t1 = now;
		}
	else
		self._state.Value = {
			p0 = p0;
			p1 = target;
			t0 = now;
			t1 = now + Math.map(math.abs(remainingDist), 0, 1, 0, transitionTime);
		}
	end
end

function TimedTween:_computeState(now)
	local state = self._state.Value
	local p

	local duration = math.max(0, state.t1 - state.t0)
	if duration == 0 then
		p = state.p1
	else
		p = Math.map(math.clamp(now, state.t0, state.t1), state.t0, state.t1, state.p0, state.p1)
	end

	local rtime = math.abs(state.p1 - p)*duration

	local v
	if rtime > 0 and duration > 0 then
		v = (state.p1 - state.p0)/duration
	else
		v = 0
	end

	return {
		p = p;
		v = v;
		rtime = rtime;
	}
end


return TimedTween