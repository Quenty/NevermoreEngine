--[=[
	@class SpringTransitionModel
]=]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local TransitionModel = require("TransitionModel")
local SpringObject = require("SpringObject")
local Promise = require("Promise")
local Maid = require("Maid")

local SpringTransitionModel = setmetatable({}, BasicPane)
SpringTransitionModel.ClassName = "SpringTransitionModel"
SpringTransitionModel.__index = SpringTransitionModel

function SpringTransitionModel.new(showTarget, hideTarget)
	local self = setmetatable(BasicPane.new(), SpringTransitionModel)

	self._transitionModel = TransitionModel.new()
	self._transitionModel:BindToPaneVisbility(self)
	self._maid:GiveTask(self._transitionModel)

	self._showTarget = showTarget or 1
	if hideTarget then
		self._hideTarget = hideTarget
	else
		self._hideTarget = 0*self._showTarget
	end

	self._springObject = SpringObject.new(self._hideTarget)
	self._springObject.Speed = 30
	self._maid:GiveTask(self._springObject)

	self._transitionModel:SetPromiseShow(function(maid, doNotAnimate)
		return self:_promiseShow(maid, doNotAnimate)
	end)
	self._transitionModel:SetPromiseHide(function(maid, doNotAnimate)
		return self:_promiseHide(maid, doNotAnimate)
	end)

	return self
end

function SpringTransitionModel:BindToPaneVisbility(pane)
	local maid = Maid.new()

	maid:GiveTask(pane.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self:SetVisible(isVisible, doNotAnimate)
	end))

	self:SetVisible(pane:IsVisible())

	self._maid._visibleBinding = maid

	return function()
		if self._maid._visibleBinding == maid then
			self._maid._visibleBinding = nil
		end
	end
end

function SpringTransitionModel:SetSpeed(speed)
	self._springObject.Speed = speed
end

function SpringTransitionModel:SetDamper(damper)
	self._springObject.Damper = damper
end

function SpringTransitionModel:ObserveRenderStepped()
	return self._springObject:ObserveRenderStepped()
end

function SpringTransitionModel:PromiseShow(doNotAnimate)
	return self._transitionModel:PromiseShow(doNotAnimate)
end

function SpringTransitionModel:PromiseHide(doNotAnimate)
	return self._transitionModel:PromiseHide(doNotAnimate)
end

function SpringTransitionModel:PromiseToggle(doNotAnimate)
	return self._transitionModel:PromiseToggle(doNotAnimate)
end

function SpringTransitionModel:_promiseShow(maid)
	local promise = Promise.new()
	maid:GiveTask(promise)

	self._springObject.t = self._showTarget

	return maid:GivePromise(self._springObject:PromiseFinished())
end

function SpringTransitionModel:_promiseHide(maid)
	local promise = Promise.new()
	maid:GiveTask(promise)

	self._springObject.t = self._hideTarget

	return maid:GivePromise(self._springObject:PromiseFinished())
end

return SpringTransitionModel