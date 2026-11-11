--!strict
--[=[
	@class SpringTransitionModel
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local SpringObject = require("SpringObject")
local SpringUtils = require("SpringUtils")
local TransitionModel = require("TransitionModel")

local SpringTransitionModel = setmetatable({}, TransitionModel)
SpringTransitionModel.ClassName = "SpringTransitionModel"
SpringTransitionModel.__index = SpringTransitionModel

export type SpringTransitionModel<T> =
	typeof(setmetatable(
		{} :: {
			_showTarget: any,
			_hideTarget: any,
			_springObject: any,
		},
		{} :: typeof({ __index = SpringTransitionModel })
	))
	& TransitionModel.TransitionModel

--[=[
	A transition model that has a spring underlying it. Very useful
	for animations on tracks that need to be on a spring.

	@param showTarget T? -- Defaults to 1
	@param hideTarget T? -- Defaults to 0*showTarget
	@return SpringTransitionModel<T>
]=]
function SpringTransitionModel.new<T>(showTarget: T?, hideTarget: T?): SpringTransitionModel<T>
	local self: SpringTransitionModel<T> = setmetatable(TransitionModel.new() :: any, SpringTransitionModel)

	self._showTarget = showTarget or 1
	self._hideTarget = hideTarget

	self._springObject = self._maid:Add(SpringObject.new(self:_computeHideTarget()))
	self._springObject.Speed = 30

	self:SetPromiseShow(function(maid, doNotAnimate)
		return self:_promiseShow(maid, doNotAnimate)
	end)
	self:SetPromiseHide(function(maid, doNotAnimate)
		return self:_promiseHide(maid, doNotAnimate)
	end)

	return self
end

--[=[
	Returns true if it's a spring transition model

	@param value any
	@return boolean
]=]
function SpringTransitionModel.isSpringTransitionModel(value: any): boolean
	return DuckTypeUtils.isImplementation(SpringTransitionModel, value)
end

--[=[
	Sets the show target for the transition model

	@param showTarget T?
	@param doNotAnimate boolean?
]=]
function SpringTransitionModel.SetShowTarget<T>(self: SpringTransitionModel<T>, showTarget: T?, doNotAnimate: boolean?)
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
function SpringTransitionModel.SetHideTarget<T>(self: SpringTransitionModel<T>, hideTarget: T?, doNotAnimate: boolean?)
	self._hideTarget = hideTarget

	if self:IsVisible() then
		self._springObject:SetTarget(self._showTarget, doNotAnimate)
	else
		self._springObject:SetTarget(self:_computeHideTarget(), doNotAnimate)
	end
end

--[=[
	Returns the spring's velocity

	@return T
]=]
function SpringTransitionModel.GetVelocity<T>(self: SpringTransitionModel<T>)
	return self._springObject.Velocity
end

--[=[
	Sets the springs epsilon. This can affect how long the spring takes
	to finish.

	@param epsilon number
]=]
function SpringTransitionModel.SetEpsilon<T>(self: SpringTransitionModel<T>, epsilon: number)
	assert(type(epsilon) == "number", "Bad epsilon")

	self._springObject.Epsilon = epsilon
end

--[=[
	Sets the springs speed

	@param speed number
]=]
function SpringTransitionModel.SetSpeed<T>(self: SpringTransitionModel<T>, speed: number | Observable.Observable<T>)
	assert(type(speed) == "number", "Bad speed")

	self._springObject.Speed = speed
end

--[=[
	Sets the springs damper

	@param damper number
]=]
function SpringTransitionModel.SetDamper<T>(self: SpringTransitionModel<T>, damper: number | Observable.Observable<T>)
	assert(type(damper) == "number", "Bad damper")

	self._springObject.Damper = damper
end

--[=[
	Observes the spring animating
	@return Observable<T>
]=]
function SpringTransitionModel.ObserveRenderStepped<T>(self: SpringTransitionModel<T>): Observable.Observable<T>
	return self._springObject:ObserveRenderStepped()
end

--[=[
	Alias to spring transition model observation!

	@return Observable<T>
]=]
function SpringTransitionModel.Observe<T>(self: SpringTransitionModel<T>): Observable.Observable<T>
	return self._springObject:Observe()
end

function SpringTransitionModel._promiseShow<T>(
	self: SpringTransitionModel<T>,
	maid: Maid.Maid,
	doNotAnimate: boolean?
): Promise.Promise<()>
	self._springObject:SetTarget(self._showTarget, doNotAnimate)

	if doNotAnimate then
		return Promise.resolved()
	else
		return maid:GivePromise(self._springObject:PromiseFinished())
	end
end

function SpringTransitionModel._promiseHide<T>(
	self: SpringTransitionModel<T>,
	maid: Maid.Maid,
	doNotAnimate: boolean?
): Promise.Promise<()>
	self._springObject:SetTarget(self:_computeHideTarget(), doNotAnimate)

	if doNotAnimate then
		return Promise.resolved()
	else
		return maid:GivePromise(self._springObject:PromiseFinished())
	end
end

function SpringTransitionModel._computeHideTarget<T>(self: SpringTransitionModel<T>): any
	if self._hideTarget then
		return SpringUtils.toLinearIfNeeded(self._hideTarget)
	else
		return 0 * SpringUtils.toLinearIfNeeded(self._showTarget) :: any
	end
end

return SpringTransitionModel
