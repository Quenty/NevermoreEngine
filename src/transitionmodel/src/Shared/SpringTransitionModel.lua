--[=[
	@class SpringTransitionModel
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local TransitionModel = require("TransitionModel")
local SpringObject = require("SpringObject")
local Promise = require("Promise")
local Maid = require("Maid")
local SpringUtils = require("SpringUtils")

local SpringTransitionModel = setmetatable({}, BasicPane)
SpringTransitionModel.ClassName = "SpringTransitionModel"
SpringTransitionModel.__index = SpringTransitionModel

--[=[
	A transition model that has a spring underlying it. Very useful
	for animations on tracks that need to be on a spring.

	@param showTarget T? -- Defaults to 1
	@param hideTarget T? -- Defaults to 0*showTarget
	@return SpringTransitionModel<T>
]=]
function SpringTransitionModel.new(showTarget, hideTarget)
	local self = setmetatable(BasicPane.new(), SpringTransitionModel)

	self._showTarget = showTarget or 1
	self._hideTarget = hideTarget

	self._transitionModel = self._maid:Add(TransitionModel.new())
	self._transitionModel:BindToPaneVisbility(self)

	self._springObject = self._maid:Add(SpringObject.new(self:_computeHideTarget()))
	self._springObject.Speed = 30

	self._transitionModel:SetPromiseShow(function(maid, doNotAnimate)
		return self:_promiseShow(maid, doNotAnimate)
	end)
	self._transitionModel:SetPromiseHide(function(maid, doNotAnimate)
		return self:_promiseHide(maid, doNotAnimate)
	end)

	return self
end

--[=[
	Sets the show target for the transition model

	@param showTarget T?
	@param doNotAnimate boolean?
]=]
function SpringTransitionModel:SetShowTarget(showTarget, doNotAnimate)
	self._showTarget = SpringUtils.toLinearIfNeeded(showTarget or 1)

	if self:IsVisible() then
		self._springObject:SetTarget(self._showTarget, doNotAnimate)
	else
		self._springObject:SetTarget(self:_computeHideTarget(), doNotAnimate)
	end
end

--[=[
	Sets the hide target for the transition model

	@param hideTarget T?
	@param doNotAnimate boolean?
]=]
function SpringTransitionModel:SetHideTarget(hideTarget, doNotAnimate)
	self._hideTarget = hideTarget

	if self:IsVisible() then
		self._springObject:SetTarget(self._showTarget, doNotAnimate)
	else
		self._springObject:SetTarget(self:_computeHideTarget(), doNotAnimate)
	end
end

--[=[
	Returns true if showing is complete
	@return boolean
]=]
function SpringTransitionModel:IsShowingComplete()
	return self._transitionModel:IsShowingComplete()
end

--[=[
	Returns true if hiding is complete
	@return boolean
]=]
function SpringTransitionModel:IsHidingComplete()
	return self._transitionModel:IsHidingComplete()
end

--[=[
	Observe is showing is complete
	@return Observable<boolean>
]=]
function SpringTransitionModel:ObserveIsShowingComplete()
	return self._transitionModel:ObserveIsShowingComplete()
end

--[=[
	Observe is hiding is complete
	@return Observable<boolean>
]=]
function SpringTransitionModel:ObserveIsHidingComplete()
	return self._transitionModel:ObserveIsHidingComplete()
end

--[=[
	Binds the transition model to the actual visiblity of the pane

	@param pane BasicPane
	@return function -- Cleanup function
]=]
function SpringTransitionModel:BindToPaneVisbility(pane)
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
	Returns the spring's velocity

	@return T
]=]
function SpringTransitionModel:GetVelocity()
	return self._springObject.Velocity
end

--[=[
	Sets the springs epsilon. This can affect how long the spring takes
	to finish.

	@param epsilon number
]=]
function SpringTransitionModel:SetEpsilon(epsilon)
	assert(type(epsilon) == "number", "Bad epsilon")

	self._springObject.Epsilon = epsilon
end

--[=[
	Sets the springs speed

	@param speed number
]=]
function SpringTransitionModel:SetSpeed(speed)
	assert(type(speed) == "number", "Bad speed")

	self._springObject.Speed = speed
end

--[=[
	Sets the springs damper

	@param damper number
]=]
function SpringTransitionModel:SetDamper(damper)
	assert(type(damper) == "number", "Bad damper")

	self._springObject.Damper = damper
end

--[=[
	Observes the spring animating
	@return Observable<T>
]=]
function SpringTransitionModel:ObserveRenderStepped()
	return self._springObject:ObserveRenderStepped()
end

--[=[
	Alias to spring transition model observation!

	@return Observable<T>
]=]
function SpringTransitionModel:Observe()
	return self._springObject:Observe()
end

--[=[
	Shows the model and promises when the showing is complete.

	@param doNotAnimate boolean
	@return Promise
]=]
function SpringTransitionModel:PromiseShow(doNotAnimate)
	return self._transitionModel:PromiseShow(doNotAnimate)
end

--[=[
	Hides the model and promises when the showing is complete.

	@param doNotAnimate boolean
	@return Promise
]=]
function SpringTransitionModel:PromiseHide(doNotAnimate)
	return self._transitionModel:PromiseHide(doNotAnimate)
end

--[=[
	Toggles the model and promises when the transition is complete.

	@param doNotAnimate boolean
	@return Promise
]=]
function SpringTransitionModel:PromiseToggle(doNotAnimate)
	return self._transitionModel:PromiseToggle(doNotAnimate)
end

function SpringTransitionModel:_promiseShow(maid, doNotAnimate)
	self._springObject:SetTarget(self._showTarget, doNotAnimate)

	if doNotAnimate then
		return Promise.resolved()
	else
		return maid:GivePromise(self._springObject:PromiseFinished())
	end
end

function SpringTransitionModel:_promiseHide(maid, doNotAnimate)
	self._springObject:SetTarget(self:_computeHideTarget(), doNotAnimate)

	if doNotAnimate then
		return Promise.resolved()
	else
		return maid:GivePromise(self._springObject:PromiseFinished())
	end
end

function SpringTransitionModel:_computeHideTarget()
	if self._hideTarget then
		return SpringUtils.toLinearIfNeeded(self._hideTarget)
	else
		return 0*SpringUtils.toLinearIfNeeded(self._showTarget)
	end
end

return SpringTransitionModel