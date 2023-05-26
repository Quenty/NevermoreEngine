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
function Spring.new(initial, clock)
	local target = initial or 0
	clock = clock or os.clock
	return setmetatable({
		_clock = clock;
		_time0 = clock();
		_position0 = target;
		_velocity0 = 0*target;
		_target = target;
		_damper = 1;
		_speed = 1;
	}, Spring)
end

--[=[
	Impulses the spring, increasing velocity by the amount given. This is useful to make something shake,
	like a Mac password box failing.

	@param velocity T -- The velocity to impulse with
	@return ()
]=]
function Spring:Impulse(velocity)
	self.Velocity = self.Velocity + velocity
end

--[=[
	Instantly skips the spring forwards by that amount time
	@param delta number -- Time to skip forwards
	@return ()
]=]
function Spring:TimeSkip(delta)
	local now = self._clock()
	local position, velocity = self:_positionVelocity(now+delta)
	self._position0 = position
	self._velocity0 = velocity
	self._time0 = now
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
function Spring:__index(index)
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
		error(("%q is not a valid member of Spring"):format(tostring(index)), 2)
	end
end

function Spring:__newindex(index, value)
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
		self._damper = value
		self._time0 = now
	elseif index == "Speed" or index == "s" then
		local position, velocity = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = velocity
		self._speed = value < 0 and 0 or value
		self._time0 = now
	elseif index == "Clock" then
		local position, velocity = self:_positionVelocity(now)
		self._position0 = position
		self._velocity0 = velocity
		self._clock = value
		self._time0 = value()
	else
		error(("%q is not a valid member of Spring"):format(tostring(index)), 2)
	end
end

function Spring:_positionVelocity(now)
	local p0 = self._position0
	local v0 = self._velocity0
	local p1 = self._target
	local d = self._damper
	local s = self._speed

	local t = s*(now - self._time0)
	local d2 = d*d

	local h, si, co
	if d2 < 1 then
		h = math.sqrt(1 - d2)
		local ep = math.exp(-d*t)/h
		co, si = ep*math.cos(h*t), ep*math.sin(h*t)
	elseif d2 == 1 then
		h = 1
		local ep = math.exp(-d*t)/h
		co, si = ep, ep*t
	else
		h = math.sqrt(d2 - 1)
		local u = math.exp((-d + h)*t)/(2*h)
		local v = math.exp((-d - h)*t)/(2*h)
		co, si = u + v, u - v
	end

	local a0 = h*co + d*si
	local a1 = 1 - (h*co + d*si)
	local a2 = si/s

	local b0 = -s*si
	local b1 = s*si
	local b2 = h*co - d*si

	return
		a0*p0 + a1*p1 + a2*v0,
		b0*p0 + b1*p1 + b2*v0
end

return Spring
