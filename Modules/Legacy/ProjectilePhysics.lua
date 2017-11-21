local Physics={}

local tick			=tick
local v3			=Vector3.new

Physics.Projectile = {}
Physics.NumberProjectile = {}
Physics.VectorProjectile = {}

function Physics.Projectile.New(Initial)
	local x0 = tick()                     -- tick0
	local p0 = Initial or 0               -- Position0
	local v0 = Initial and 0*Initial or 0 -- Velocity0
	local a0 = v0                         -- Acceleration

	local function PositionVelocity(tick)
		local dt = tick-x0
		return p0 + v0*dt + 0.5*dt*dt*a0,
		       v0 + a0*dt
	end
	local Projectile
	Projectile = setmetatable({
			Impulse = function(_,v)
				Projectile.Velocity=Projectile.Velocity+v
			end;
			TimeSkip = function(_, dt)
				local tick = tick()
				local p, v = PositionVelocity(tick+dt)
				x0 = tick
				v0 = v
				p0 = p
			end;
		}, {
		__index = function(self, Index)
			if Index=="Value" or Index=="Position" or Index=="p" then
				local p, v = PositionVelocity(tick())
				return p
			elseif Index=="Velocity" or Index=="v" then
				local p, v = PositionVelocity(tick())
				return v
			elseif Index=="Acceleration" or Index=="a" or Index == "Gravity" then
				return a0
			else
				error(Index .. " is not a valid member of Projectile")
			end
		end;
		__newindex = function(self, Index, Value)
			local tick = tick()
			if Index=="Value" or Index=="Position" or Index=="p" then
				local p, v = PositionVelocity(tick)
				p0 = Value
				v0 = v
				x0 = tick
			elseif Index=="Velocity" or Index=="v" then
				local p, v = PositionVelocity(tick)
				p0 = p
				v0 = Value
				x0 = tick
			elseif Index=="Acceleration" or Index=="a" or Index == "Gravity" then
				local p, v = PositionVelocity(tick)
				a0 = Value
				p0 = p
				v0 = v
				x0 = tick
			else
				error(Index .. " is not a valid member of Projectile")
			end
		end;
	})
	return Projectile
end

function Physics.NumberProjectile.New(Initial)
	return Physics.Projectile.New(Initial)
end

function Physics.VectorProjectile.New(Initial)
	return Physics.Projectile.New(Initial or v3())
end

return Physics