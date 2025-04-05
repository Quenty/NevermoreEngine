--[=[
	@class TimedTransitionModel
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local TransitionModel = require("TransitionModel")
local TimedTween = require("TimedTween")
local Promise = require("Promise")
local Maid = require("Maid")

local TimedTransitionModel = setmetatable({}, BasicPane)
TimedTransitionModel.ClassName = "TimedTransitionModel"
TimedTransitionModel.__index = TimedTransitionModel

--[=[
	A transition model that has a spring underlying it. Very useful
	for animations on tracks that need to be on a spring.

	@param transitionTime number? -- Optional
	@return TimedTransitionModel<T>
]=]
function TimedTransitionModel.new(transitionTime: number?)
	local self = setmetatable(BasicPane.new(), TimedTransitionModel)

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

function TimedTransitionModel:SetTransitionTime(transitionTime: number)
	self._timedTween:SetTransitionTime(transitionTime)
end

--[=[
	Returns true if showing is complete
	@return boolean
]=]
function TimedTransitionModel:IsShowingComplete(): boolean
	return self._transitionModel:IsShowingComplete()
end

--[=[
	Returns true if hiding is complete
	@return boolean
]=]
function TimedTransitionModel:IsHidingComplete(): boolean
	return self._transitionModel:IsHidingComplete()
end

--[=[
	Observe is showing is complete
	@return Observable<boolean>
]=]
function TimedTransitionModel:ObserveIsShowingComplete()
	return self._transitionModel:ObserveIsShowingComplete()
end

--[=[
	Observe is hiding is complete
	@return Observable<boolean>
]=]
function TimedTransitionModel:ObserveIsHidingComplete()
	return self._transitionModel:ObserveIsHidingComplete()
end

--[=[
	Binds the transition model to the actual visiblity of the pane

	@param pane BasicPane
	@return function -- Cleanup function
]=]
function TimedTransitionModel:BindToPaneVisbility(pane)
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
	@return Observable<T>
]=]
function TimedTransitionModel:ObserveRenderStepped()
	return self._timedTween:ObserveRenderStepped()
end

--[=[
	Alias to spring transition model observation!

	@return Observable<T>
]=]
function TimedTransitionModel:Observe()
	return self._timedTween:Observe()
end

--[=[
	Shows the model and promises when the showing is complete.

	@param doNotAnimate boolean?
	@return Promise
]=]
function TimedTransitionModel:PromiseShow(doNotAnimate: boolean?)
	return self._transitionModel:PromiseShow(doNotAnimate)
end

--[=[
	Hides the model and promises when the showing is complete.

	@param doNotAnimate boolean?
	@return Promise
]=]
function TimedTransitionModel:PromiseHide(doNotAnimate: boolean?)
	return self._transitionModel:PromiseHide(doNotAnimate)
end

--[=[
	Toggles the model and promises when the transition is complete.

	@param doNotAnimate boolean
	@return Promise
]=]
function TimedTransitionModel:PromiseToggle(doNotAnimate: boolean?)
	return self._transitionModel:PromiseToggle(doNotAnimate)
end

function TimedTransitionModel:_promiseShow(maid, doNotAnimate: boolean?)
	self._timedTween:Show(doNotAnimate)

	if doNotAnimate then
		return Promise.resolved()
	else
		return maid:GivePromise(self._timedTween:PromiseFinished())
	end
end

function TimedTransitionModel:_promiseHide(maid, doNotAnimate: boolean?)
	self._timedTween:Hide(doNotAnimate)

	if doNotAnimate then
		return Promise.resolved()
	else
		return maid:GivePromise(self._timedTween:PromiseFinished())
	end
end


return TimedTransitionModel