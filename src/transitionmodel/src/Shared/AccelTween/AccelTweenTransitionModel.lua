--!strict
--[=[
	@class AccelTweenTransitionModel
]=]

local require = require(script.Parent.loader).load(script)

local AccelTween = require("AccelTween")
local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Signal = require("Signal")
local StepUtils = require("StepUtils")
local TransitionModel = require("TransitionModel")

-- Covers a 0 to 1 range in about 0.14 seconds, matching the acceleration the rest of Nevermore
-- animates interface state at.
local DEFAULT_ACCELERATION = 200

local AccelTweenTransitionModel = setmetatable({}, TransitionModel)
AccelTweenTransitionModel.ClassName = "AccelTweenTransitionModel"
AccelTweenTransitionModel.__index = AccelTweenTransitionModel

export type AccelTweenTransitionModel =
	typeof(setmetatable(
		{} :: {
			_showTarget: number,
			_hideTarget: number?,
			_accelTween: AccelTween.AccelTween,
			_targetChanged: Signal.Signal<()>,
		},
		{} :: typeof({ __index = AccelTweenTransitionModel })
	))
	& TransitionModel.TransitionModel

--[=[
	A transition model that has an [AccelTween] underlying it. Reaches its target in minimum
	time under a maximum acceleration, so unlike [SpringTransitionModel] it arrives at a
	definite time and never overshoots.

	Only numbers are supported. [AccelTween] solves on a scalar, so there is no equivalent of
	the linear value conversion [SpringTransitionModel] uses to animate Vector3s and Color3s.

	@param showTarget number? -- Defaults to 1
	@param hideTarget number? -- Defaults to 0
	@return AccelTweenTransitionModel
]=]
function AccelTweenTransitionModel.new(showTarget: number?, hideTarget: number?): AccelTweenTransitionModel
	assert(type(showTarget) == "number" or showTarget == nil, "Bad showTarget")
	assert(type(hideTarget) == "number" or hideTarget == nil, "Bad hideTarget")

	local self: AccelTweenTransitionModel = setmetatable(TransitionModel.new() :: any, AccelTweenTransitionModel)

	self._showTarget = showTarget or 1
	self._hideTarget = hideTarget

	self._targetChanged = self._maid:Add(Signal.new() :: any)

	self._accelTween = AccelTween.new(DEFAULT_ACCELERATION)
	self._accelTween.pt = self:_computeHideTarget()

	self:SetPromiseShow(function(maid, doNotAnimate)
		return self:_promiseShow(maid, doNotAnimate)
	end)
	self:SetPromiseHide(function(maid, doNotAnimate)
		return self:_promiseHide(maid, doNotAnimate)
	end)

	return self
end

--[=[
	Returns true if it's an accel tween transition model

	@param value any
	@return boolean
]=]
function AccelTweenTransitionModel.isAccelTweenTransitionModel(value: any): boolean
	return DuckTypeUtils.isImplementation(AccelTweenTransitionModel, value)
end

--[=[
	Sets the show target for the transition model

	@param showTarget number?
	@param doNotAnimate boolean?
]=]
function AccelTweenTransitionModel.SetShowTarget(
	self: AccelTweenTransitionModel,
	showTarget: number?,
	doNotAnimate: boolean?
)
	assert(type(showTarget) == "number" or showTarget == nil, "Bad showTarget")

	self._showTarget = showTarget or 1

	if self:IsVisible() then
		self:_setTarget(self._showTarget, doNotAnimate)
	else
		self:_setTarget(self:_computeHideTarget(), doNotAnimate)
	end
end

--[=[
	Sets the hide target for the transition model

	@param hideTarget number?
	@param doNotAnimate boolean?
]=]
function AccelTweenTransitionModel.SetHideTarget(
	self: AccelTweenTransitionModel,
	hideTarget: number?,
	doNotAnimate: boolean?
)
	assert(type(hideTarget) == "number" or hideTarget == nil, "Bad hideTarget")

	self._hideTarget = hideTarget

	if self:IsVisible() then
		self:_setTarget(self._showTarget, doNotAnimate)
	else
		self:_setTarget(self:_computeHideTarget(), doNotAnimate)
	end
end

--[=[
	Sets the maximum acceleration used to reach the target. Higher is faster.

	@param acceleration number
]=]
function AccelTweenTransitionModel.SetAcceleration(self: AccelTweenTransitionModel, acceleration: number)
	assert(type(acceleration) == "number", "Bad acceleration")

	self._accelTween.a = acceleration

	-- Retimes the solve, so anything stepping off this model has to pick up the new arrival time
	self._targetChanged:Fire()
end

--[=[
	Gets the maximum acceleration used to reach the target

	@return number
]=]
function AccelTweenTransitionModel.GetAcceleration(self: AccelTweenTransitionModel): number
	return self._accelTween.a
end

--[=[
	Returns the current position of the tween

	@return number
]=]
function AccelTweenTransitionModel.GetPosition(self: AccelTweenTransitionModel): number
	return self._accelTween.p
end

--[=[
	Returns the tween velocity

	@return number
]=]
function AccelTweenTransitionModel.GetVelocity(self: AccelTweenTransitionModel): number
	return self._accelTween.v
end

--[=[
	Returns the time left before the tween attains its target

	@return number
]=]
function AccelTweenTransitionModel.GetRemainingTime(self: AccelTweenTransitionModel): number
	return self._accelTween.rtime
end

--[=[
	Observes the tween animating on the animation step
	@return Observable<number>
]=]
function AccelTweenTransitionModel.ObserveRenderStepped(self: AccelTweenTransitionModel): Observable.Observable<number>
	return self:ObserveOnSignal(StepUtils.getAnimationStepSignal())
end

--[=[
	Observes the tween animating on a specific signal

	@param signal RBXScriptSignal
	@return Observable<number>
]=]
function AccelTweenTransitionModel.ObserveOnSignal(
	self: AccelTweenTransitionModel,
	signal: RBXScriptSignal
): Observable.Observable<number>
	return Observable.new(function(sub)
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
			sub:Fire(self._accelTween.p)
			return self._accelTween.rtime > 0
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(self._targetChanged:Connect(startAnimate))
		startAnimate()

		return maid
	end) :: any
end

--[=[
	Alias to accel tween transition model observation!

	@return Observable<number>
]=]
function AccelTweenTransitionModel.Observe(self: AccelTweenTransitionModel): Observable.Observable<number>
	return self:ObserveRenderStepped()
end

function AccelTweenTransitionModel._promiseShow(
	self: AccelTweenTransitionModel,
	maid: Maid.Maid,
	doNotAnimate: boolean?
): Promise.Promise<()>
	self:_setTarget(self._showTarget, doNotAnimate)

	if doNotAnimate then
		return Promise.resolved()
	else
		return maid:GivePromise(self:_promiseFinished())
	end
end

function AccelTweenTransitionModel._promiseHide(
	self: AccelTweenTransitionModel,
	maid: Maid.Maid,
	doNotAnimate: boolean?
): Promise.Promise<()>
	self:_setTarget(self:_computeHideTarget(), doNotAnimate)

	if doNotAnimate then
		return Promise.resolved()
	else
		return maid:GivePromise(self:_promiseFinished())
	end
end

--[=[
	Promises when the tween has arrived at its target.

	[AccelTween] solves the arrival time analytically, but that time is only meaningful against
	the clock the tween reads, which may not be wall time. Poll it off the animation step rather
	than scheduling against `rtime`.

	@private
	@return Promise
]=]
function AccelTweenTransitionModel._promiseFinished(self: AccelTweenTransitionModel): Promise.Promise<()>
	if self._accelTween.rtime <= 0 then
		return Promise.resolved()
	end

	local maid = Maid.new()
	local promise = maid:Add(Promise.new())

	local startAnimate, stopAnimate = StepUtils.bindToSignal(StepUtils.getAnimationStepSignal(), function()
		if self._accelTween.rtime > 0 then
			return true
		end

		promise:Resolve()
		return false
	end)

	maid:GiveTask(stopAnimate)
	maid:GiveTask(self._targetChanged:Connect(startAnimate))
	startAnimate()

	self._maid[promise] = maid

	promise:Finally(function()
		self._maid[promise] = nil
	end)

	maid:GiveTask(function()
		self._maid[promise] = nil
	end)

	return promise
end

function AccelTweenTransitionModel._setTarget(
	self: AccelTweenTransitionModel,
	target: number,
	doNotAnimate: boolean?
): ()
	if doNotAnimate then
		-- Position, velocity, and target in one write, so the tween cannot report itself as
		-- still travelling between them
		self._accelTween.pt = target
	else
		self._accelTween.t = target
	end

	self._targetChanged:Fire()
end

function AccelTweenTransitionModel._computeHideTarget(self: AccelTweenTransitionModel): number
	if self._hideTarget then
		return self._hideTarget
	else
		return 0
	end
end

return AccelTweenTransitionModel
