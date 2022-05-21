--[=[
	@class SpringObject
]=]

local require = require(script.Parent.loader).load(script)

local RunService= game:GetService("RunService")

local Spring = require("Spring")
local Maid = require("Maid")
local Signal = require("Signal")
local StepUtils = require("StepUtils")
local Observable = require("Observable")
local SpringUtils = require("SpringUtils")
local Blend = require("Blend")
local Rx = require("Rx")

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
		Changed = Signal.new();
	}, SpringObject)

--[=[
	Event fires when the spring value changes
	@prop Changed Signal<()> -- Fires whenever the spring initially changes state
	@within ValueObject
]=]
	self._maid:GiveTask(self.Changed)

	if target then
		self.Target = target
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
	return type(value) == "table" and getmetatable(value) == SpringObject
end

--[=[
	Observes the spring animating
	@return Observable<T>
]=]
function SpringObject:ObserveRenderStepped()
	return self:ObserveOnSignal(RunService.RenderStepped)
end

function SpringObject:ObserveVelocityOnRenderStepped()
	return self:ObserveVelocityOnSignal(RunService.RenderStepped)
end

function SpringObject:ObserveVelocityOnSignal(signal)
	return Observable.new(function(sub)
		local maid = Maid.new()

		local startAnimate, stopAnimate = StepUtils.bindToSignal(signal, function()
			local animating = SpringUtils.animating(self._currentSpring)
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
			local animating, position = SpringUtils.animating(self._currentSpring)
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
	return (SpringUtils.animating(self._currentSpring))
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
	elseif SpringObject[index] then
		return SpringObject[index]
	else
		error(("%q is not a member of SpringObject"):format(tostring(index)))
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
		local observable = Blend.toPropertyObservable(value) or Rx.of(value)

		self._maid._targetSub = observable:Subscribe(function(unconverted)
			local converted = SpringUtils.toLinearIfNeeded(unconverted)
			self:_getSpringForType(converted).Target = converted

			self.Changed:Fire()
		end)
	elseif index == "Damper" or index == "d" then
		local observable = assert(Blend.toNumberObservable(value), "Invalid damper")

		self._maid._damperSub = observable:Subscribe(function(unconverted)
			assert(type(unconverted) == "number", "Bad damper")

			self._currentSpring.Damper = unconverted
			self.Changed:Fire()
		end)
	elseif index == "Speed" or index == "s" then
		local observable = assert(Blend.toNumberObservable(value), "Invalid speed")

		self._maid._speedSub = observable:Subscribe(function(unconverted)
			assert(type(unconverted) == "number", "Bad damper")

			self._currentSpring.Speed = unconverted
			self.Changed:Fire()
		end)
	elseif index == "Clock" then
		assert(type(value) == "function", "Bad clock value")
		self._currentSpring.Clock = value
		self.Changed:Fire()
	else
		error(("%q is not a member of SpringObject"):format(tostring(index)))
	end
end

function SpringObject:_getSpringForType(converted)
	if rawget(self, "_currentSpring") == nil then
		-- only happens on init
		rawset(self, "_currentSpring", Spring.new(converted))
		return self._currentSpring
	else
		local currentType = typeof(SpringUtils.fromLinearIfNeeded(self._currentSpring.Value))
		if currentType == typeof(converted) then
			return self._currentSpring
		else
			local oldDamper = self._currentSpring.d
			local oldSpeed = self._currentSpring.s

			self._currentSpring = Spring.new(converted)
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