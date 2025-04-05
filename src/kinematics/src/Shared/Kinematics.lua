--!nocheck
--[=[
	Basic kinematics calculator that can be used like a spring. See [Spring] also.

	@class Kinematics
]=]

local Kinematics = {}
Kinematics.ClassName = "Kinematics"

export type Clock = () -> number

--[=[
	Constructs a new kinematics class.

	```lua
	local kinematics = Kinematics.new(0)
	kinematics.Acceleration = -32
	kinematics.Velocity = 10

	print(kinematics.Position) --> 0
	task.wait(1)
	print(kinematics.Position) --> -10
	```

	@param initial T -- The initial parameter is a number or Vector3 (anything with * number and addition/subtraction).
	@param clock? () -> number -- The clock function is optional, and is used to update the kinematics class
	@return Kinematics<T>
]=]
function Kinematics.new<T>(initial: T, clock: Clock?)
	initial = initial or 0

	local self = setmetatable({}, Kinematics)

	rawset(self, "_clock", clock or os.clock)
	rawset(self, "_position0", initial)
	rawset(self, "_velocity0", 0 * initial)
	rawset(self, "_acceleration", 0 * initial)
	rawset(self, "_speed", 1)
	rawset(self, "_time0", self._clock())

	return self
end

--[=[
	Impulses the current kinematics object, applying velocity to it.
	@param velocity T
]=]
function Kinematics:Impulse<T>(velocity: T)
	self.Velocity = self.Velocity + velocity
end

--[=[
	Skips forward in the set amount of time dictated by `delta`
	@param delta number
]=]
function Kinematics:TimeSkip(delta: number)
	assert(type(delta) == "number", "Bad delta")

	local now = self._clock()
	local position, velocity = self:_positionVelocity(now + delta)
	rawset(self, "_position0", position)
	rawset(self, "_velocity0", velocity)
	rawset(self, "_time0", now)
end

--[=[
	Sets data from some external source all at once.
	This is useful for synchronizing the network.

	@param startTime number
	@param position0 T
	@param velocity0 T
	@param acceleration T
]=]
function Kinematics:SetData<T>(startTime: number, position0: T, velocity0: T, acceleration: T)
	rawset(self, "_time0", startTime)
	rawset(self, "_position0", position0)
	rawset(self, "_velocity0", velocity0)
	rawset(self, "_acceleration", acceleration)
end

--[=[
	Gets and sets the current position of the Kinematics
	@prop Position T
	@within Kinematics
]=]

--[=[
	Gets and sets the current velocity of the Kinematics
	@prop Velocity T
	@within Kinematics
]=]

--[=[
	Gets and sets the acceleration.
	@prop Acceleration T
	@within Kinematics
]=]

--[=[
	Gets and sets the start time.
	@prop StartTime T
	@within Kinematics
]=]

--[=[
	Gets and set the start position
	@prop StartPosition T
	@within Kinematics
]=]

--[=[
	Sets the start velocity
	@prop StartVelocity T
	@within Kinematics
]=]

--[=[
	Sets the playback speed
	@prop Speed number
	@within Kinematics
]=]

--[=[
	Returns how old the kinematics is
	@prop Age number
	@readonly
	@within Kinematics
]=]

--[=[
	The current clock object to syncronize the kienmatics against.

	@prop Clock () -> number
	@within Kinematics
]=]

function Kinematics:__index(index: string)
	local now = self._clock()

	if Kinematics[index] then
		return Kinematics[index]
	elseif index == "Position" then
		local position, _ = self:_positionVelocity(now)
		return position
	elseif index == "Velocity" then
		local _, velocity = self:_positionVelocity(now)
		return velocity
	elseif index == "Acceleration" then
		return rawget(self, "_acceleration")
	elseif index == "StartTime" then
		return rawget(self, "_time0")
	elseif index == "StartPosition" then
		return rawget(self, "_position0")
	elseif index == "StartVelocity" then
		return rawget(self, "_velocity0")
	elseif index == "Speed" then
		return rawget(self, "_speed")
	elseif index == "Age" then
		return self._clock() - rawget(self, "_time0")
	elseif index == "Clock" then
		return rawget(self, "_clock")
	else
		error(string.format("%q is not a valid member of Kinematics", tostring(index)), 2)
	end
end

function Kinematics:__newindex(index: string, value)
	local now = self._clock()
	if index == "Position" then
		local _, velocity = self:_positionVelocity(now)
		rawset(self, "_position0", value)
		rawset(self, "_velocity0", velocity)
	elseif index == "Velocity" then
		local position, _ = self:_positionVelocity(now)
		rawset(self, "_position0", position)
		rawset(self, "_velocity0", value)
	elseif index == "Acceleration" then
		local position, velocity = self:_positionVelocity(now)
		rawset(self, "_position0", position)
		rawset(self, "_velocity0", velocity)
		rawset(self, "_acceleration", value)
	elseif index == "Speed" then
		local position, velocity = self:_positionVelocity(now)
		rawset(self, "_position0", position)
		rawset(self, "_velocity0", velocity)
		rawset(self, "_speed", value)
	elseif index == "Clock" then
		local position, velocity = self:_positionVelocity(now)
		rawset(self, "_position0", position)
		rawset(self, "_velocity0", velocity)
		rawset(self, "_clock", value)
		rawset(self, "_time0", value())
	else
		error(string.format("%q is not a valid member of Kinematics", tostring(index)), 2)
	end
	rawset(self, "_time0", now)
end

function Kinematics:_positionVelocity<T>(now: number): (T, T)
	local s: number = rawget(self, "_speed")
	local t0: number = rawget(self, "_time0")
	local dt: number = s * (now - t0)
	local a0: T = rawget(self, "_acceleration")
	local v0: T = rawget(self, "_velocity0")
	local p0: T = rawget(self, "_position0")
	return p0 + v0*dt + 0.5*dt*dt*a0,
	       v0 + a0*dt
end

return Kinematics