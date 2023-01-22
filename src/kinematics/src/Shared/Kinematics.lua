--[=[
	Basic kinematics calculator that can be used like a spring.
	@class Kinematics
]=]

local Kinematics = {}
Kinematics.ClassName = "Kinematics"

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
function Kinematics.new(initial, clock)
	initial = initial or 0

	local self = setmetatable({}, Kinematics)

	rawset(self, "_clock", clock or os.clock)
	rawset(self, "_position0", initial)
	rawset(self, "_velocity0", 0*initial)
	rawset(self, "_acceleration", 0*initial)
	rawset(self, "_speed", 0)
	rawset(self, "_time0", self._clock())

	return self
end

--[=[
	Impulses the current kinematics object, applying velocity to it.
	@param velocity T
]=]
function Kinematics:Impulse(velocity)
	self.Velocity = self.Velocity + velocity
end

--[=[
	Skips forward in the set amount of time dictated by `delta`
	@param delta number
]=]
function Kinematics:TimeSkip(delta)
	assert(type(delta) == "number", "Bad delta")

	local now = self._clock()
	local position, velocity = self:_positionVelocity(now+delta)
	rawset(self, "_position0", position)
	rawset(self, "_velocity0", velocity)
	rawset(self, "_time0", now)
end

--[=[
	Sets data from some external source
	@param startTime number
	@param position0 T
	@param velocity0 T
	@param acceleration T
]=]
function Kinematics:SetData(startTime, position0, velocity0, acceleration)
	rawset(self, "_time0", startTime)
	rawset(self, "_position0", position0)
	rawset(self, "_velocity0", velocity0)
	rawset(self, "_acceleration", acceleration)
end

function Kinematics:__index(index)
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
		error(("%q is not a valid member of Kinematics"):format(tostring(index)), 2)
	end
end

function Kinematics:__newindex(index, value)
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
		error(("%q is not a valid member of Kinematics"):format(tostring(index)), 2)
	end
	rawset(self, "_time0", now)
end

function Kinematics:_positionVelocity(now)
	local s = rawget(self, "_speed")
	local dt = s*(now - rawget(self, "_time0"))
	local a0 = rawget(self, "_acceleration")
	local v0 = rawget(self, "_velocity0")
	local p0 = rawget(self, "_position0")
	return p0 + v0*dt + 0.5*dt*dt*a0,
	       v0 + a0*dt
end

return Kinematics
