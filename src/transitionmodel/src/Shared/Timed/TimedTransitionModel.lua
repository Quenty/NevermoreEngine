--!strict
--[=[
	@class TimedTransitionModel
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local TimedTween = require("TimedTween")
local TransitionModel = require("TransitionModel")
local ValueObject = require("ValueObject")

local TimedTransitionModel = setmetatable({}, TransitionModel)
TimedTransitionModel.ClassName = "TimedTransitionModel"
TimedTransitionModel.__index = TimedTransitionModel

export type TimedTransitionModel =
	typeof(setmetatable(
		{} :: {
			_timedTween: TimedTween.TimedTween,
		},
		{} :: typeof({ __index = TimedTransitionModel })
	))
	& TransitionModel.TransitionModel

--[=[
	A transition model that has a spring underlying it. Very useful
	for animations on tracks that need to be on a spring.

	@param transitionTime ValueObject.Mountable<number>? -- Optional
	@return TimedTransitionModel
]=]
function TimedTransitionModel.new(transitionTime: ValueObject.Mountable<number>?): TimedTransitionModel
	local self: TimedTransitionModel = setmetatable(TransitionModel.new() :: any, TimedTransitionModel)

	self._timedTween = self._maid:Add(TimedTween.new(transitionTime))

	self:SetPromiseShow(function(maid, doNotAnimate)
		return self:_promiseShow(maid, doNotAnimate)
	end)
	self:SetPromiseHide(function(maid, doNotAnimate)
		return self:_promiseHide(maid, doNotAnimate)
	end)

	return self
end

--[=[
	Returns true if it's a timed transition model

	@param value any
	@return boolean
]=]
function TimedTransitionModel.isTimedTransitionModel(value: any): boolean
	return DuckTypeUtils.isImplementation(TimedTransitionModel, value)
end

--[=[
	Sets the transition time

	@param transitionTime number
]=]
function TimedTransitionModel.SetTransitionTime(
	self: TimedTransitionModel,
	transitionTime: ValueObject.Mountable<number>
): () -> ()
	return self._timedTween:SetTransitionTime(transitionTime)
end

--[=[
	Observes the spring animating
	@return Observable<number>
]=]
function TimedTransitionModel.ObserveRenderStepped(self: TimedTransitionModel): Observable.Observable<number>
	return self._timedTween:ObserveRenderStepped()
end

--[=[
	Alias to spring transition model observation!

	@return Observable<number>
]=]
function TimedTransitionModel.Observe(self: TimedTransitionModel): Observable.Observable<number>
	return self._timedTween:Observe()
end

function TimedTransitionModel._promiseShow(
	self: TimedTransitionModel,
	maid,
	doNotAnimate: boolean?
): Promise.Promise<()>
	self._timedTween:Show(doNotAnimate)

	if doNotAnimate then
		return Promise.resolved()
	else
		return maid:GivePromise(self._timedTween:PromiseFinished())
	end
end

function TimedTransitionModel._promiseHide(
	self: TimedTransitionModel,
	maid: Maid.Maid,
	doNotAnimate: boolean?
): Promise.Promise<()>
	self._timedTween:Hide(doNotAnimate)

	if doNotAnimate then
		return Promise.resolved()
	else
		return maid:GivePromise(self._timedTween:PromiseFinished())
	end
end

return TimedTransitionModel
