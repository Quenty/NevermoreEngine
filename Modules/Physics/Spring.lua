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
	Spring:Impulse(number/Vector3 Velocity)
		Impulses the spring, increasing velocity by the amount given
]]


local Spring = {}

-- @param Initial A number or Vector3 (anything with * number and addition/subtraction defined)
function Spring.new(Initial)
	local self = setmetatable({}, Spring)

	local Target = Initial or 0
	rawset(self, "_time0", tick())
	rawset(self, "_position0", Target)
	rawset(self, "_velocity0", 0*Target)
	rawset(self, "_target", Target)
	rawset(self, "_damper", 1)
	rawset(self, "_speed", 1)

	return self
end

function Spring:__index(Index)
	if Spring[Index] then
		return Spring[Index]
	elseif Index == "Value" or Index == "Position" or Index == "p" then
		local Position, _ = self:PositionVelocity(tick())
		return Position
	elseif Index == "Velocity" or Index == "v" then
		local _, Velocity = self:PositionVelocity(tick())
		return Velocity
	elseif Index == "Target" or Index == "t" then
		return rawget(self, "_target")
	elseif Index == "Damper" or Index == "d" then
		return rawget(self, "_damper")
	elseif Index == "Speed" or Index == "s" then
		return rawget(self, "_speed")
	else
		error(("'%s' is not a valid member of Spring"):format(tostring(Index)), 2)
	end
end

function Spring:__newindex(Index, Value)
	local Time = tick()

	if Index == "Value" or Index == "Position" or Index == "p" then
		local _, Velocity = self:PositionVelocity(Time)
		rawset(self, "_position0", Value)
		rawset(self, "_velocity0", Velocity)
	elseif Index == "Velocity" or Index == "v" then
		local Position, _ = self:PositionVelocity(Time)
		rawset(self, "_position0", Position)
		rawset(self, "_velocity0", Value)
	elseif Index == "Target" or Index == "t" then
		local Position, Velocity = self:PositionVelocity(Time)
		rawset(self, "_position0", Position)
		rawset(self, "_velocity0", Velocity)
		rawset(self, "_target", Value)
	elseif Index == "Damper" or Index == "d" then
		local Position, Velocity = self:PositionVelocity(Time)
		rawset(self, "_position0", Position)
		rawset(self, "_velocity0", Velocity)
		rawset(self, "_damper", math.clamp(Value, 0, 1))
	elseif Index == "Speed" or Index == "s" then
		local Position, Velocity = self:PositionVelocity(Time)
		rawset(self, "_position0", Position)
		rawset(self, "_velocity0", Velocity)
		rawset(self, "_speed", Value < 0 and 0 or Value)
	else
		error(("'%s' is not a valid member of Spring"):format(tostring(Index)), 2)
	end
	
	rawset(self, "_time0", Time)
end

function Spring:PositionVelocity(Time)
	local dt = Time - rawget(self, "_time0")
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

function Spring:Impulse(Velocity)
	self.Velocity = self.Velocity + Velocity
end

function Spring:TimeSkip(Delta)
	local Time = tick()
	local Position, Velocity = self:PositionVelocity(Time+Delta)
	rawset(self, "_position0", Position)
	rawset(self, "_velocity0", Velocity)
	rawset(self, "_time0", Time)
end

return Spring