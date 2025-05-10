--!strict
--[=[
	@class TimedTransitionModel
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local TimedTween = require("TimedTween")
local TransitionModel = require("TransitionModel")

local TimedTransitionModel = setmetatable({}, BasicPane)
TimedTransitionModel.ClassName = "TimedTransitionModel"
TimedTransitionModel.__index = TimedTransitionModel

export type TimedTransitionModel = typeof(setmetatable(
	{} :: {
		_transitionModel: TransitionModel.TransitionModel,
		_timedTween: TimedTween.TimedTween,
	},
	{} :: typeof({ __index = TimedTransitionModel })
)) & BasicPane.BasicPane

--[=[
	A transition model that has a spring underlying it. Very useful
	for animations on tracks that need to be on a spring.

	@param transitionTime number? -- Optional
	@return TimedTransitionModel
]=]
function TimedTransitionModel.new(transitionTime: number?): TimedTransitionModel
	local self: TimedTransitionModel = setmetatable(BasicPane.new() :: any, TimedTransitionModel)

	self._transitionModel = self._maid:Add(TransitionModel.new())
	self._transitionModel:BindToPaneVisbility(self)

	self._timedTween = self._maid:Add(TimedTween.new(transitionTime))

	-- State
	self._transitionModel:SetPromiseShow(function(maid, doNotAnimate)
		return self:_promiseShow(maid, doNotAnimate)
	end)
	self._transitionModel:SetPromiseHide(function(maid, doNotAnimate)
		return self:_promiseHide(maid, doNotAnimate)
	end)

	return self
end

--[=[
	Sets the transition time

	@param transitionTime number
]=]
function TimedTransitionModel.SetTransitionTime(self: TimedTransitionModel, transitionTime: number)
	self._timedTween:SetTransitionTime(transitionTime)
end

--[=[
	Returns true if showing is complete
	@return boolean
]=]
function TimedTransitionModel.IsShowingComplete(self: TimedTransitionModel): boolean
	return self._transitionModel:IsShowingComplete()
end

--[=[
	Returns true if hiding is complete
	@return boolean
]=]
function TimedTransitionModel.IsHidingComplete(self: TimedTransitionModel): boolean
	return self._transitionModel:IsHidingComplete()
end

--[=[
	Observe is showing is complete
	@return Observable<boolean>
]=]
function TimedTransitionModel.ObserveIsShowingComplete(self: TimedTransitionModel): Observable.Observable<boolean>
	return self._transitionModel:ObserveIsShowingComplete()
end

--[=[
	Observe is hiding is complete
	@return Observable<boolean>
]=]
function TimedTransitionModel.ObserveIsHidingComplete(self: TimedTransitionModel): Observable.Observable<boolean>
	return self._transitionModel:ObserveIsHidingComplete()
end

--[=[
	Binds the transition model to the actual visiblity of the pane

	@param pane BasicPane
	@return function -- Cleanup function
]=]
function TimedTransitionModel.BindToPaneVisbility(self: TimedTransitionModel, pane: BasicPane.BasicPane): () -> ()
	local maid = Maid.new()

	maid:GiveTask(pane.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self:SetVisible(isVisible, doNotAnimate)
	end))
	maid:GiveTask(self.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		pane:SetVisible(isVisible, doNotAnimate)
	end))

	self:SetVisible(pane:IsVisible())

	self._maid._visibleBinding = maid

	return function()
		if not self.Destroy then
			return
		end

		if self._maid._visibleBinding == maid then
			self._maid._visibleBinding = nil
		end
	end
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

--[=[
	Shows the model and promises when the showing is complete.

	@param doNotAnimate boolean?
	@return Promise
]=]
function TimedTransitionModel.PromiseShow(self: TimedTransitionModel, doNotAnimate: boolean?): Promise.Promise<()>
	return self._transitionModel:PromiseShow(doNotAnimate)
end

--[=[
	Hides the model and promises when the showing is complete.

	@param doNotAnimate boolean?
	@return Promise
]=]
function TimedTransitionModel.PromiseHide(self: TimedTransitionModel, doNotAnimate: boolean?): Promise.Promise<()>
	return self._transitionModel:PromiseHide(doNotAnimate)
end

--[=[
	Toggles the model and promises when the transition is complete.

	@param doNotAnimate boolean
	@return Promise
]=]
function TimedTransitionModel.PromiseToggle(self: TimedTransitionModel, doNotAnimate: boolean?): Promise.Promise<()>
	return self._transitionModel:PromiseToggle(doNotAnimate)
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
