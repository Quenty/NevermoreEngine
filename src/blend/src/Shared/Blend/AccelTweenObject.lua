--!strict
--[=[
	A wrapper around [AccelTween] that can be observed and emits events. Similar to [SpringObject].

	@class AccelTweenObject
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local AccelTween = require("AccelTween")
local Blend = require("Blend")
local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Signal = require("Signal")
local StepUtils = require("StepUtils")

local AccelTweenObject = {}
AccelTweenObject.ClassName = "AccelTweenObject"
AccelTweenObject.__index = AccelTweenObject

export type AccelTweenObject = typeof(setmetatable(
	{} :: {
		-- Public
		Changed: Signal.Signal<()>,
		Observe: (self: AccelTweenObject) -> Observable.Observable<number>,
		ObserveRenderStepped: (self: AccelTweenObject) -> Observable.Observable<number>,
		ObserveTarget: (self: AccelTweenObject) -> Observable.Observable<number>,
		ObserveVelocityOnRenderStepped: (self: AccelTweenObject) -> Observable.Observable<number>,
		PromiseFinished: (self: AccelTweenObject, signal: RBXScriptSignal?) -> Promise.Promise<boolean>,
		ObserveVelocityOnSignal: (self: AccelTweenObject, signal: RBXScriptSignal) -> Observable.Observable<number>,
		ObserveOnSignal: (self: AccelTweenObject, signal: RBXScriptSignal) -> Observable.Observable<number>,
		IsAnimating: (self: AccelTweenObject) -> boolean,
		SetTarget: <T>(self: AccelTweenObject, target: T, doNotAnimate: boolean?) -> () -> (),
		SetVelocity: <T>(self: AccelTweenObject, velocity: T) -> (),
		SetPosition: <T>(self: AccelTweenObject, position: T) -> (),
		SetAcceleration: (self: AccelTweenObject, acceleration: number | Observable.Observable<number>) -> (),
		SetPositionTarget: <T>(self: AccelTweenObject, positionTarget: T) -> (),
		Destroy: (self: AccelTweenObject) -> (),
		_applyTarget: (self: AccelTweenObject, target: number, doNotAnimate: boolean?) -> (),
		_applyVelocity: (self: AccelTweenObject, velocity: number) -> (),
		_applyPosition: (self: AccelTweenObject, position: number) -> (),
		_applyAcceleration: (self: AccelTweenObject, acceleration: number) -> (),
		_ensureAccelTween: (self: AccelTweenObject) -> AccelTween.AccelTween,
		_getInitInfo: (self: AccelTweenObject) -> {
			Acceleration: number,
		},

		-- Properties
		Value: number,
		Position: number,
		p: number,
		Velocity: number,
		v: number,
		Target: number,
		t: number,
		Acceleration: number,
		a: number,
		RemainingTime: number,
		rtime: number,
		PositionTarget: number,
		pt: number,

		-- Members
		_maid: Maid.Maid,
		_currentAccelTween: AccelTween.AccelTween?,
		_initInfo: {
			Acceleration: number,
		}?,
	},
	AccelTweenObject
))

--[=[
	Constructs a new AccelTweenObject.

	The accel tween object is initially initialized at the target position with a velocity of 0.
	When setting a target, velocity, or position, it will emit [Changed].

	@param target number?
	@param acceleration number | Observable<number> | ValueObject<number> | NumberValue | any
	@return AccelTweenObject
]=]
function AccelTweenObject.new(target: number?, acceleration): AccelTweenObject
	local self: AccelTweenObject = setmetatable({
		_maid = Maid.new(),
		Changed = Signal.new(),
	}, AccelTweenObject) :: any

	--[=[
		Event fires when the accel tween value changes.
		@prop Changed Signal<()> -- Fires whenever the accel tween changes state
		@within AccelTweenObject
	]=]
	self._maid:GiveTask(self.Changed)

	self:_ensureAccelTween()

	if target ~= nil then
		self:SetPositionTarget(target)
	else
		self:SetPositionTarget(0)
	end

	if acceleration ~= nil then
		self.Acceleration = acceleration
	end

	return self :: any
end

--[=[
	Returns whether an object is an AccelTweenObject.
	@param value any
	@return boolean
]=]
function AccelTweenObject.isAccelTweenObject(value: any): boolean
	return DuckTypeUtils.isImplementation(AccelTweenObject, value)
end

--[=[
	Observes the accel tween animating on render stepped.
	@return Observable<number>
]=]
function AccelTweenObject:ObserveRenderStepped()
	return self:ObserveOnSignal(RunService.RenderStepped)
end

--[=[
	Alias for [ObserveRenderStepped] on the client, uses [RunService.Stepped] on the server.
	@return Observable<number>
]=]
function AccelTweenObject:Observe()
	if RunService:IsClient() then
		return self:ObserveOnSignal(RunService.RenderStepped)
	else
		return self:ObserveOnSignal(RunService.Stepped)
	end
end

--[=[
	Observes the current target of the accel tween.
	@return Observable<number>
]=]
function AccelTweenObject:ObserveTarget()
	return Observable.new(function(sub)
		local maid = Maid.new()

		local lastTarget = self.Target

		maid:GiveTask(self.Changed:Connect(function()
			local target = self.Target
			if lastTarget ~= target then
				lastTarget = target
				sub:Fire(target)
			end
		end))

		sub:Fire(lastTarget)

		return maid
	end)
end

--[=[
	Observes the current velocity of the accel tween on render stepped.
	@return Observable<number>
]=]
function AccelTweenObject:ObserveVelocityOnRenderStepped()
	return self:ObserveVelocityOnSignal(RunService.RenderStepped)
end

--[=[
	Promises that the accel tween is done animating. This is relatively expensive.

	@param signal RBXScriptSignal | nil
	@return Promise<boolean>
]=]
function AccelTweenObject:PromiseFinished(signal)
	signal = signal or RunService.RenderStepped

	local maid = Maid.new()
	local promise = maid:Add(Promise.new())

	local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
		local animating = self:IsAnimating()
		if not animating then
			promise:Resolve(true)
		end

		return animating
	end)

	maid:GiveTask(stopAnimate)
	maid:GiveTask(self.Changed:Connect(startAnimate))
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

function AccelTweenObject:ObserveVelocityOnSignal(signal)
	return Observable.new(function(sub)
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
			local accelTween = rawget(self, "_currentAccelTween")
			if not accelTween then
				return false
			end

			if accelTween.rtime > 0 then
				sub:Fire(accelTween.v)
				return true
			else
				sub:Fire(0)
				return false
			end
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(self.Changed:Connect(startAnimate))
		startAnimate()

		return maid
	end)
end

--[=[
	Observes the accel tween animating.
	@param signal RBXScriptSignal
	@return Observable<number>
]=]
function AccelTweenObject:ObserveOnSignal(signal)
	return Observable.new(function(sub)
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
			local accelTween = rawget(self, "_currentAccelTween")
			if not accelTween then
				return false
			end

			sub:Fire(accelTween.p)
			return accelTween.rtime > 0
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(self.Changed:Connect(startAnimate))
		startAnimate()

		return maid
	end)
end

--[=[
	Returns true when the accel tween is animating.
	@return boolean -- True if animating
]=]
function AccelTweenObject:IsAnimating(): boolean
	local accelTween = rawget(self, "_currentAccelTween")
	if not accelTween then
		return false
	end

	return accelTween.rtime > 0
end

--[=[
	Sets the target position. If doNotAnimate is true, then animation will be skipped.

	@param target number
	@param doNotAnimate boolean? -- Whether or not to animate
]=]
function AccelTweenObject:SetTarget<T>(target: T, doNotAnimate: boolean?)
	assert(target ~= nil, "Bad target")

	local observable = Blend.toPropertyObservable(target)
	if not observable then
		assert(type(target) == "number", "Bad target")
		self._maid._targetSub = nil
		self:_applyTarget(target, doNotAnimate)
		return function() end
	end

	local sub
	self._maid._targetSub = nil
	if doNotAnimate then
		local isFirst = true
		sub = observable:Subscribe(function(value)
			assert(type(value) == "number", "Bad target")

			local wasFirst = isFirst
			isFirst = false
			self:_applyTarget(value, wasFirst)
		end)
	else
		sub = observable:Subscribe(function(value)
			assert(type(value) == "number", "Bad target")
			self:_applyTarget(value, doNotAnimate)
		end)
	end

	self._maid._targetSub = sub

	return function()
		if self._maid._targetSub == sub then
			self._maid._targetSub = nil
		end
	end
end

function AccelTweenObject:_applyTarget(target: number, doNotAnimate: boolean?)
	self:_ensureAccelTween():SetTarget(target, doNotAnimate)
	self.Changed:Fire()
end

--[=[
	Sets the velocity for the accel tween.

	@param velocity number | Observable<number>
]=]
function AccelTweenObject:SetVelocity<T>(velocity: T)
	assert(velocity ~= nil, "Bad velocity")

	local observable = Blend.toPropertyObservable(velocity)
	if not observable then
		assert(type(velocity) == "number", "Bad velocity")
		self._maid._velocitySub = nil
		self:_applyVelocity(velocity)
	else
		self._maid._velocitySub = observable:Subscribe(function(value)
			assert(type(value) == "number", "Bad velocity")
			self:_applyVelocity(value)
		end)
	end
end

function AccelTweenObject:_applyVelocity(velocity: number)
	self:_ensureAccelTween().v = velocity
	self.Changed:Fire()
end

--[=[
	Sets the position for the accel tween.

	@param position number | Observable<number>
]=]
function AccelTweenObject:SetPosition<T>(position: T)
	assert(position ~= nil, "Bad position")

	local observable = Blend.toPropertyObservable(position)
	if not observable then
		assert(type(position) == "number", "Bad position")
		self._maid._positionSub = nil
		self:_applyPosition(position)
	else
		self._maid._positionSub = observable:Subscribe(function(value)
			assert(type(value) == "number", "Bad position")
			self:_applyPosition(value)
		end)
	end
end

function AccelTweenObject:_applyPosition(position: number)
	self:_ensureAccelTween().p = position
	self.Changed:Fire()
end

--[=[
	Sets the maximum acceleration for the accel tween.

	@param acceleration number | Observable<number>
]=]
function AccelTweenObject:SetAcceleration(acceleration)
	assert(acceleration ~= nil, "Bad acceleration")

	if type(acceleration) == "number" then
		self._maid._accelerationSub = nil
		self:_applyAcceleration(acceleration)
	else
		local observable = assert(Blend.toPropertyObservable(acceleration), "Invalid acceleration")

		self._maid._accelerationSub = observable:Subscribe(function(value)
			assert(type(value) == "number", "Bad acceleration")
			self:_applyAcceleration(value)
		end)
	end
end

function AccelTweenObject:_applyAcceleration(acceleration: number)
	assert(type(acceleration) == "number", "Bad acceleration")

	local accelTween = rawget(self, "_currentAccelTween")
	if accelTween then
		accelTween.a = acceleration
	else
		self:_getInitInfo().Acceleration = acceleration
	end

	self.Changed:Fire()
end

--[=[
	Sets the current and target position for the accel tween, and sets the velocity for it to 0.

	@param positionTarget number | Observable<number>
]=]
function AccelTweenObject:SetPositionTarget<T>(positionTarget: T)
	assert(positionTarget ~= nil, "Bad positionTarget")

	local observable = Blend.toPropertyObservable(positionTarget)
	if not observable then
		assert(type(positionTarget) == "number", "Bad positionTarget")
		self._maid._positionTargetSub = nil
		self:_ensureAccelTween().pt = positionTarget
		self.Changed:Fire()
	else
		self._maid._positionTargetSub = observable:Subscribe(function(value)
			assert(type(value) == "number", "Bad positionTarget")
			self:_ensureAccelTween().pt = value
			self.Changed:Fire()
		end)
	end
end

(AccelTweenObject :: any).__index = function(self, index)
	local accelTween = rawget(self, "_currentAccelTween")

	if AccelTweenObject[index] then
		return AccelTweenObject[index]
	elseif index == "Value" or index == "Position" or index == "p" then
		if accelTween then
			return accelTween.p
		else
			return 0
		end
	elseif index == "Velocity" or index == "v" then
		if accelTween then
			return accelTween.v
		else
			return 0
		end
	elseif index == "Target" or index == "t" then
		if accelTween then
			return accelTween.t
		else
			return 0
		end
	elseif index == "Acceleration" or index == "a" then
		if accelTween then
			return accelTween.a
		else
			return (self :: any):_getInitInfo().Acceleration
		end
	elseif index == "RemainingTime" or index == "rtime" then
		if accelTween then
			return accelTween.rtime
		else
			return 0
		end
	elseif index == "PositionTarget" or index == "pt" then
		if accelTween then
			return accelTween.t
		else
			return 0
		end
	elseif index == "_currentAccelTween" then
		local found = rawget(self, "_currentAccelTween")
		if found then
			return found
		end

		error("Internal error: Cannot get _currentAccelTween, as we aren't initialized yet")
	else
		error(string.format("%q is not a member of AccelTweenObject", tostring(index)))
	end
end

function AccelTweenObject:__newindex(index, value)
	if index == "Value" or index == "Position" or index == "p" then
		self:SetPosition(value)
	elseif index == "Velocity" or index == "v" then
		self:SetVelocity(value)
	elseif index == "Target" or index == "t" then
		self:SetTarget(value)
	elseif index == "Acceleration" or index == "a" then
		self:SetAcceleration(value)
	elseif index == "PositionTarget" or index == "pt" then
		self:SetPositionTarget(value)
	elseif index == "RemainingTime" or index == "rtime" then
		error("Cannot set RemainingTime")
	elseif index == "_currentAccelTween" then
		error("Cannot set _currentAccelTween")
	else
		error(string.format("%q is not a member of AccelTweenObject", tostring(index)))
	end
end

function AccelTweenObject:_ensureAccelTween(): AccelTween.AccelTween
	local currentAccelTween = rawget(self, "_currentAccelTween")
	if currentAccelTween then
		return currentAccelTween
	end

	local initInfo = self:_getInitInfo()
	local newAccelTween = AccelTween.new(initInfo.Acceleration)
	rawset(self, "_currentAccelTween", newAccelTween)

	return newAccelTween
end

function AccelTweenObject:_getInitInfo()
	local currentAccelTween = rawget(self, "_currentAccelTween")
	if currentAccelTween then
		error("Should not have currentAccelTween")
	end

	local foundInitInfo = rawget(self, "_initInfo")
	if foundInitInfo then
		return foundInitInfo
	end

	local value = {
		Acceleration = 1,
	}

	rawset(self, "_initInfo", value)

	return value
end

--[=[
	Cleans up the accel tween object and sets the metatable to nil.
]=]
function AccelTweenObject:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return AccelTweenObject
