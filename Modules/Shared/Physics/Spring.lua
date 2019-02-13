--[[
class Spring

Description:
	A physical model of a spring, useful in many applications. Properties only evaluate
	upon index making this model good for lazy applications

API:
	Spring = Spring.new(number position)
		Creates a new spring in 1D
	Spring = Spring.new(Vector3 position)
		Creates a new spring in 3D

	Spring.Position
		Returns the current position
	Spring.Velocity
		Returns the current velocity
	Spring.Target
		Returns the target
	Spring.Damper
		Returns the damper
	Spring.Speed
		Returns the speed

	Spring.Target = number/Vector3
		Sets the target
	Spring.Position = number/Vector3
		Sets the position
	Spring.Velocity = number/Vector3
		Sets the velocity
	Spring.Damper = number [0, 1]
		Sets the spring damper, defaults to 1
	Spring.Speed = number [0, infinity)
		Sets the spring speed, defaults to 1

	Spring:TimeSkip(number DeltaTime)
		Instantly skips the spring forwards by that amount of time
	Spring:Impulse(number/Vector3 velocity)
		Impulses the spring, increasing velocity by the amount given
]]


local Spring = {}

--- Creates a new spring
-- @param initial A number or Vector3 (anything with * number and addition/subtraction defined)
function Spring.new(initial)
	local self = setmetatable({}, Spring)

	local target = initial or 0
	rawset(self, "_time0", tick())
	rawset(self, "_position0", target)
	rawset(self, "_velocity0", 0*target)
	rawset(self, "_target", target)
	rawset(self, "_damper", 1)
	rawset(self, "_speed", 1)

	return self
end

--- Impulse the spring with a change in velocity
-- @param velocity The velocity to impulse with
function Spring:Impulse(velocity)
	self.Velocity = self.Velocity + velocity
end

--- Skip forwards in time
-- @param delta Time to skip forwards
function Spring:TimeSkip(delta)
	local time = tick()
	local position, velocity = self:_positionVelocity(time+delta)
	rawset(self, "_position0", position)
	rawset(self, "_velocity0", velocity)
	rawset(self, "_time0", time)
end

function Spring:__index(index)
	if Spring[index] then
		return Spring[index]
	elseif index == "Value" or index == "Position" or index == "p" then
		local position, _ = self:_positionVelocity(tick())
		return position
	elseif index == "Velocity" or index == "v" then
		local _, velocity = self:_positionVelocity(tick())
		return velocity
	elseif index == "Target" or index == "t" then
		return rawget(self, "_target")
	elseif index == "Damper" or index == "d" then
		return rawget(self, "_damper")
	elseif index == "Speed" or index == "s" then
		return rawget(self, "_speed")
	else
		error(("%q is not a valid member of Spring"):format(tostring(index)), 2)
	end
end

function Spring:__newindex(index, value)
	local time = tick()

	if index == "Value" or index == "Position" or index == "p" then
		local _, velocity = self:_positionVelocity(time)
		rawset(self, "_position0", value)
		rawset(self, "_velocity0", velocity)
	elseif index == "Velocity" or index == "v" then
		local position, _ = self:_positionVelocity(time)
		rawset(self, "_position0", position)
		rawset(self, "_velocity0", value)
	elseif index == "Target" or index == "t" then
		local position, velocity = self:_positionVelocity(time)
		rawset(self, "_position0", position)
		rawset(self, "_velocity0", velocity)
		rawset(self, "_target", value)
	elseif index == "Damper" or index == "d" then
		local position, velocity = self:_positionVelocity(time)
		rawset(self, "_position0", position)
		rawset(self, "_velocity0", velocity)
		rawset(self, "_damper", math.clamp(value, 0, 1))
	elseif index == "Speed" or index == "s" then
		local position, velocity = self:_positionVelocity(time)
		rawset(self, "_position0", position)
		rawset(self, "_velocity0", velocity)
		rawset(self, "_speed", value < 0 and 0 or value)
	else
		error(("%q is not a valid member of Spring"):format(tostring(index)), 2)
	end

	rawset(self, "_time0", time)
end

function Spring:_positionVelocity(time)
	local dt = time - rawget(self, "_time0")
	local p0 = rawget(self, "_position0")
	local v0 = rawget(self, "_velocity0")
	local t = rawget(self, "_target")
	local d = rawget(self, "_damper")
	local s = rawget(self, "_speed")

	local c0 = p0-t
	if s == 0 then
		return p0, 0
	elseif d<1 then
		local c	 = (1-d*d)^0.5
		local c1 = (v0/s+d*c0)/c
		local co = math.cos(c*s*dt)
		local si = math.sin(c*s*dt)
		local e  = 2.718281828459045^(d*s*dt)
		return t+(c0*co+c1*si)/e,
		       s*((c*c1-d*c0)*co-(c*c0+d*c1)*si)/e
	else
		local c1 = v0/s+c0
		local e  = 2.718281828459045^(s*dt)
		return t+(c0+c1*s*dt)/e,
		       s*(c1-c0-c1*s*dt)/e
	end
end

return Spring
