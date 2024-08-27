--[=[
	This is like a [Spring], but it can be observed, and emits events. It handles [Observable]s and

	@class SpringObject
]=]

local require = require(script.Parent.loader).load(script)

local RunService= game:GetService("RunService")

local Blend = require("Blend")
local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Rx = require("Rx")
local Signal = require("Signal")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")
local StepUtils = require("StepUtils")

local SpringObject = {}
SpringObject.ClassName = "SpringObject"
SpringObject.__index = SpringObject

--[=[
	Constructs a new SpringObject.
	@param target T
	@param speed number | Observable<number> | ValueObject<number> | NumberValue | any
	@param damper number | Observable<number> | NumberValue | any
	@return Spring<T>
]=]
function SpringObject.new(target, speed, damper)
	local self = setmetatable({
		_maid = Maid.new();
		_epsilon = 1e-6;
		Changed = Signal.new();
	}, SpringObject)

--[=[
	Event fires when the spring value changes
	@prop Changed Signal<()> -- Fires whenever the spring initially changes state
	@within SpringObject
]=]
	self._maid:GiveTask(self.Changed)

	if target then
		self:SetTarget(target)
	else
		self:_getSpringForType(0)
	end

	if speed then
		self.Speed = speed
	end

	if damper then
		self.Damper = damper
	end

	return self
end

--[=[
	Returns whether an object is a SpringObject.
	@param value any
	@return boolean
]=]
function SpringObject.isSpringObject(value)
	return DuckTypeUtils.isImplementation(SpringObject, value)
end

--[=[
	Observes the spring animating
	@return Observable<T>
]=]
function SpringObject:ObserveRenderStepped()
	return self:ObserveOnSignal(RunService.RenderStepped)
end

--[=[
	Alias for [ObserveRenderStepped]

	@return Observable<T>
]=]
function SpringObject:Observe()
	if RunService:IsClient() then
		return self:ObserveOnSignal(RunService.RenderStepped)
	else
		return self:ObserveOnSignal(RunService.Stepped)
	end
end

--[=[
	Observes the current target of the spring

	@return Observable<T>
]=]
function SpringObject:ObserveTarget()
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

function SpringObject:ObserveVelocityOnRenderStepped()
	return self:ObserveVelocityOnSignal(RunService.RenderStepped)
end

--[=[
	Promises that the spring is done, based upon the animating property
	Relatively expensive.

	@param signal RBXScriptSignal | nil
	@return Observable<T>
]=]
function SpringObject:PromiseFinished(signal)
	signal = signal or RunService.RenderStepped

	local maid = Maid.new()
	local promise = Promise.new()
	maid:GiveTask(promise)

	-- TODO: Mathematical solution?
	local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
		local animating = SpringUtils.animating(self._currentSpring, self._epsilon)
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

function SpringObject:ObserveVelocityOnSignal(signal)
	return Observable.new(function(sub)
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
			local animating = SpringUtils.animating(self._currentSpring, self._epsilon)
			if animating then
				sub:Fire(SpringUtils.fromLinearIfNeeded(self._currentSpring.Velocity))
			else
				sub:Fire(SpringUtils.fromLinearIfNeeded(0*self._currentSpring.Velocity))
			end
			return animating
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(self.Changed:Connect(startAnimate))
		startAnimate()

		return maid
	end)
end

--[=[
	Observes the spring animating
	@param signal RBXScriptSignal
	@return Observable<T>
]=]
function SpringObject:ObserveOnSignal(signal)
	return Observable.new(function(sub)
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
			local animating, position = SpringUtils.animating(self._currentSpring, self._epsilon)
			sub:Fire(SpringUtils.fromLinearIfNeeded(position))
			return animating
		end)

		maid:GiveTask(stopAnimate)
		maid:GiveTask(self.Changed:Connect(startAnimate))
		startAnimate()

		return maid
	end)
end

--[=[
	Returns true when we're animating
	@return boolean -- True if animating
]=]
function SpringObject:IsAnimating()
	return (SpringUtils.animating(self._currentSpring, self._epsilon))
end

--[=[
	Impulses the spring, increasing velocity by the amount given. This is useful to make something shake,
	like a Mac password box failing.

	@param velocity T -- The velocity to impulse with
	@return ()
]=]
function SpringObject:Impulse(velocity)
	self._currentSpring:Impulse(SpringUtils.toLinearIfNeeded(velocity))
	self.Changed:Fire()
end

--[=[
	Sets the actual target. If doNotAnimate is set, then animation will be skipped.

	@param value T -- The target to set
	@param doNotAnimate boolean? -- Whether or not to animate
	@return ()
]=]
function SpringObject:SetTarget(value, doNotAnimate)
	local observable = Blend.toPropertyObservable(value) or Rx.of(value)

	if doNotAnimate then
		local isFirst = true

		self._maid._targetSub = observable:Subscribe(function(unconverted)
			local converted = SpringUtils.toLinearIfNeeded(unconverted)
			assert(converted, "Not a valid converted value")

			local spring = self:_getSpringForType(converted)
			spring:SetTarget(converted, isFirst)
			isFirst = false

			self.Changed:Fire()
		end)
	else
		self._maid._targetSub = observable:Subscribe(function(unconverted)
			local converted = SpringUtils.toLinearIfNeeded(unconverted)
			self:_getSpringForType(converted).Target = converted

			self.Changed:Fire()
		end)
	end
end

--[=[
	Instantly skips the spring forwards by that amount time
	@param delta number -- Time to skip forwards
	@return ()
]=]
function SpringObject:TimeSkip(delta)
	assert(type(delta) == "number", "Bad delta")

	self._currentSpring:TimeSkip(delta)
	self.Changed:Fire()
end

function SpringObject:__index(index)
	if index == "Value" or index == "Position" or index == "p" then
		return SpringUtils.fromLinearIfNeeded(self._currentSpring.Value)
	elseif index == "Velocity" or index == "v" then
		return SpringUtils.fromLinearIfNeeded(self._currentSpring.Velocity)
	elseif index == "Target" or index == "t" then
		return SpringUtils.fromLinearIfNeeded(self._currentSpring.Target)
	elseif index == "Damper" or index == "d" then
		return self._currentSpring.Damper
	elseif index == "Speed" or index == "s" then
		return self._currentSpring.Speed
	elseif index == "Clock" then
		return self._currentSpring.Clock
	elseif index == "Epsilon" then
		return self._epsilon
	elseif SpringObject[index] then
		return SpringObject[index]
	elseif index == "_currentSpring" then
		return rawget(self, "_currentSpring")
	else
		error(string.format("%q is not a member of SpringObject", tostring(index)))
	end
end

function SpringObject:__newindex(index, value)
	if index == "Value" or index == "Position" or index == "p" then
		local observable = Blend.toPropertyObservable(value) or Rx.of(value)

		self._maid._valueSub = observable:Subscribe(function(unconverted)
			local converted = SpringUtils.toLinearIfNeeded(unconverted)
			self:_getSpringForType(converted).Value = converted
			self.Changed:Fire()
		end)
	elseif index == "Velocity" or index == "v" then
		local observable = Blend.toPropertyObservable(value) or Rx.of(value)

		self._maid._velocitySub = observable:Subscribe(function(unconverted)
			local converted = SpringUtils.toLinearIfNeeded(unconverted)

			self:_getSpringForType(0*converted).Velocity = converted
			self.Changed:Fire()
		end)
	elseif index == "Target" or index == "t" then
		self:SetTarget(value)
	elseif index == "Damper" or index == "d" then
		local observable = assert(Blend.toNumberObservable(value), "Invalid damper")

		self._maid._damperSub = observable:Subscribe(function(unconverted)
			assert(type(unconverted) == "number", "Bad damper")

			self._currentSpring.Damper = unconverted
			self.Changed:Fire()
		end)
	elseif index == "Speed" or index == "s" then
		local observable = assert(Blend.toNumberObservable(value), "Invalid speed")
		assert(self._currentSpring, "No self._currentSpring")

		self._maid._speedSub = observable:Subscribe(function(unconverted)
			assert(type(unconverted) == "number", "Bad damper")

			self._currentSpring.Speed = unconverted
			self.Changed:Fire()
		end)
	elseif index == "Epsilon" then
		assert(type(value) == "number", "Bad value")
		rawset(self, "_epsilon", value)
	elseif index == "Clock" then
		assert(type(value) == "function", "Bad clock value")
		self._currentSpring.Clock = value
		self.Changed:Fire()
	elseif index == "_currentSpring" then
		rawset(self, "_currentSpring", value)
	else
		error(string.format("%q is not a member of SpringObject", tostring(index)))
	end
end

function SpringObject:_ensureSpringOrInitSpring()

end

function SpringObject:_getSpringForType(converted)
	if rawget(self, "_currentSpring") == nil then
		-- only happens on init
		local created = Spring.new(converted)
		rawset(self, "_currentSpring", created)
		return self._currentSpring
	else
		local currentType = typeof(SpringUtils.fromLinearIfNeeded(self._currentSpring.Value))
		if currentType == typeof(SpringUtils.fromLinearIfNeeded(converted)) then
			return self._currentSpring
		else
			local oldDamper = self._currentSpring.d
			local oldSpeed = self._currentSpring.s
			local clock = self._currentSpring.Clock

			self._currentSpring = Spring.new(converted)
			self._currentSpring.Clock = clock
			self._currentSpring.Speed = oldSpeed
			self._currentSpring.Damper = oldDamper
			return self._currentSpring
		end
	end
end

--[=[
	Cleans up the BaseObject and sets the metatable to nil
]=]
function SpringObject:Destroy()
	self._maid:DoCleaning()
	setmetatable(self, nil)
end

return SpringObject