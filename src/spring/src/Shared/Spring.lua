--!strict
--[=[
	A physical model of a spring, useful in many applications.

	A spring is an object that will compute based upon Hooke's law. Properties only evaluate
	upon index making this model good for lazy applications.

	```lua
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")

	local spring = Spring.new(Vector3.zero)

	RunService.RenderStepped:Connect(function()
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			spring.Target = Vector3.new(0, 0, 1)
		else
			spring.Target = Vector3.zero
		end

		print(spring.Position) -- A smoothed out version of the input keycode W
	end)
	```

	A good visualization can be found here, provided by Defaultio:
	https://www.desmos.com/calculator/hn2i9shxbz

	@class Spring
]=]
local Spring = {}
Spring.__index = Spring

export type SpringClock = () -> number

export type Spring<T> = typeof(setmetatable(
	{} :: {
		Position: T,
		Value: T,
		Velocity: T,
		Target: T,
		Damper: number,
		Speed: number,
		Clock: SpringClock,

		_position0: T,
		_velocity0: T,
		_time0: number,
		_target: T,
		_damper: number,
		_speed: number,
		_clock: SpringClock,
		_positionVelocity: (self: Spring<T>, now: number) -> (T, T),
	},
	{} :: typeof({ __index = Spring })
))

--[=[
	Constructs a new Spring at the position and target specified, of type T.

	```lua
	-- Linear spring
	local linearSpring = Spring.new(0)

	-- Vector2 spring
	local vector2Spring = Spring.new(Vector2.zero)

	-- Vector3 spring
	local vector3Spring = Spring.new(Vector3.zero)
	```

	@param initial T -- The initial parameter is a number or Vector3 (anything with * number and addition/subtraction).
	@param clock? () -> number -- The clock function is optional, and is used to update the spring
	@return Spring<T>
]=]
function Spring.new<T>(initial: T?, clock: SpringClock?): Spring<T>
	local p0 = initial or 0
	local springClock = clock or os.clock

	return setmetatable(
		{
			_clock = springClock,
			_time0 = springClock(),
			_position0 = p0,
			_velocity0 = 0 * (p0 :: any),
			_target = p0,
			_damper = 1,
			_speed = 1,
		} :: any,
		Spring
	) :: Spring<T>
end

--[=[
	Impulses the spring, increasing velocity by the amount given. This is useful to make something shake,
	like a Mac password box failing.

	@param velocity T -- The velocity to impulse with
	@return ()
]=]
function Spring.Impulse<T>(self: Spring<T>, velocity: T)
	self.Velocity = (self.Velocity :: any) + velocity
end

--[=[
	Instantly skips the spring forwards by that amount time
	@param delta number -- Time to skip forwards
	@return ()
]=]
function Spring.TimeSkip<T>(self: Spring<T>, delta: number)
	local now = self._clock()
	local position, velocity = self:_positionVelocity(now + delta)
	self._position0 = position
	self._velocity0 = velocity
	self._time0 = now
end

--[=[
	Sets the actual target. If doNotAnimate is set, then animation will be skipped.

	@param value T -- The target to set
	@param doNotAnimate boolean? -- Whether or not to animate
]=]
function Spring.SetTarget<T>(self: Spring<T>, value: T, doNotAnimate: boolean?)
	if doNotAnimate then
		local now = self._clock()
		self._position0 = value
		self._velocity0 = 0 * (value :: any)
		self._target = value
		self._time0 = now
	else
		self.Target = value
	end
end

--[=[
	The current position at the given clock time. Assigning the position will change the spring to have that position.

	```lua
	local spring = Spring.new(0)
	print(spring.Position) --> 0
	```

	@prop Position T
	@within Spring
]=]
--[=[
	Alias for [Spring.Position](/api/Spring#Position)

	@prop p T
	@within Spring
]=]
--[=[
	The current velocity. Assigning the velocity will change the spring to have that velocity.

	```lua
	local spring = Spring.new(0)
	print(spring.Velocity) --> 0
	```

	@prop Velocity T
	@within Spring
]=]
--[=[
	Alias for [Spring.Velocity](/api/Spring#Velocity)

	@prop v T
	@within Spring
]=]
--[=[
	The current target. Assigning the target will change the spring to have that target.

	```lua
	local spring = Spring.new(0)
	print(spring.Target) --> 0
	```

	@prop Target T
	@within Spring
]=]
--[=[
	Alias for [Spring.Target](/api/Spring#Target)
	@prop t T
	@within Spring
]=]
--[=[
	The current damper, defaults to 1. At 1 the spring is critically damped. At less than 1, it
	will be underdamped, and thus, bounce, and at over 1, it will be critically damped.

	@prop Damper number
	@within Spring
]=]
--[=[
	Alias for [Spring.Damper](/api/Spring#Damper)

	@prop d number
	@within Spring
]=]
--[=[
	The speed, defaults to 1, but should be between [0, infinity)

	@prop Speed number
	@within Spring
]=]
--[=[
	Alias for [Spring.Speed](/api/Spring#Speed)

	@prop s number
	@within Spring
]=]
--[=[
	The current clock object to syncronize the spring against.

	@prop Clock () -> number
	@within Spring
]=]
(Spring :: any).__index = function<T>(self: Spring<T>, index: any): any
	if Spring[index] then
		return Spring[index]
	elseif index == "Value" or index == "Position" or index == "p" then
		local position, _ = self:_positionVelocity(self._clock())
		return position
	elseif index == "Velocity" or index == "v" then
		local _, velocity = self:_positionVelocity(self._clock())
		return velocity
	elseif index == "Target" or index == "t" then
		return self._target
	elseif index == "Damper" or index == "d" then
		return self._damper
	elseif index == "Speed" or index == "s" then
		return self._speed
	elseif index == "Clock" then
		return self._clock
	else
		error(string.format("%q is not a valid member of Spring", tostring(index)), 2)
	end
end

function Spring.__newindex<T>(self: Spring<T>, index, value)
	local now = self._clock()

	if index == "Value" or index == "Position" or index == "p" then
		local _, velocity = self:_positionVelocity(now)
		self._position0 = value
		self._velocity0 = velocity
		self._time0 = now
	elseif index == "Velocity" or index == "v" then
		local position, _ = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = value
		self._time0 = now
	elseif index == "Target" or index == "t" then
		local position, velocity = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = velocity
		self._target = value
		self._time0 = now
	elseif index == "Damper" or index == "d" then
		local position, velocity = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = velocity
		self._damper = value :: any
		self._time0 = now
	elseif index == "Speed" or index == "s" then
		local position, velocity = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = velocity
		self._speed = if (value :: any) < 0 then 0 else value :: any
		self._time0 = now
	elseif index == "Clock" then
		local position, velocity = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = velocity
		self._clock = value :: any
		self._time0 = (value :: any)()
	else
		error(string.format("%q is not a valid member of Spring", tostring(index)), 2)
	end
end

function Spring._positionVelocity<T>(self: Spring<T>, now: number): (T, T)
	local p0 = self._position0
	local v0 = self._velocity0
	local p1 = self._target
	local d: number = self._damper
	local s: number = self._speed

	local t: number = s * (now - self._time0)
	local d2 = d * d

	local h, si, co
	if d2 < 1 then
		h = math.sqrt(1 - d2)
		local ep = math.exp(-d * t) / h
		co, si = ep * math.cos(h * t), ep * math.sin(h * t)
	elseif d2 == 1 then
		h = 1
		local ep = math.exp(-d * t) / h
		co, si = ep, ep * t
	else
		h = math.sqrt(d2 - 1)
		local u = math.exp((-d + h) * t) / (2 * h)
		local v = math.exp((-d - h) * t) / (2 * h)
		co, si = u + v, u - v
	end

	local a0: any = h * co + d * si
	local a1: any = 1 - (h * co + d * si)
	local a2: any = si / s

	local b0: any = -s * si
	local b1: any = s * si
	local b2: any = h * co - d * si

	-- stylua: ignore
	return a0 * p0 + a1 * p1 + a2 * v0,
		b0 * p0 + b1 * p1 + b2 * v0
end

return Spring
