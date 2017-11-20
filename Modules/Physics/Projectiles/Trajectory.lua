--- Returns two possible paths from Origin to Target where the magnitude of the initial velocity is InitialVelocity
-- @param Origin vector3 Origin
-- @param Target vector3 Target
-- @param InitialVelocity number
-- @param GravityForce is a positive number
-- @return tuple(vector3 LowTrajector, vector3 HighTrajectory)
local function Trajectory(Origin, Target, InitialVelocity, GravityForce)
	local g = -GravityForce
	local ox,oy,oz=Origin.x,Origin.y,Origin.z
	local rx,rz=Target.x-ox,Target.z-oz
	local tx2=rx*rx+rz*rz
	local ty=Target.y-oy
	if tx2>0 then
		local v2=InitialVelocity*InitialVelocity

		local c0=tx2/(2*(tx2+ty*ty))
		local c1=g*ty+v2
		local c22=v2*(2*g*ty+v2)-g*g*tx2
		if c22>0 then
			local c2=c22^0.5
			local t0x2=c0*(c1+c2)
			local t1x2=c0*(c1-c2)

			local tx,t0x,t1x=tx2^0.5,t0x2^0.5,t1x2^0.5

			local v0x,v0y,v0z=rx/tx*t0x,(v2-t0x2)^0.5,rz/tx*t0x
			local v1x,v1y,v1z=rx/tx*t1x,(v2-t1x2)^0.5,rz/tx*t1x

			local v0=Vector3.new(v0x,ty>g*tx2/(2*v2) and v0y or -v0y,v0z)
			local v1=Vector3.new(v1x,v1y,v1z)

			return v0,v1
		else				
			return nil, nil, Vector3.new(rx, (tx2^0.5), rz).unit * InitialVelocity
		end
	else
		local v=Vector3.new(0,InitialVelocity*(ty>0 and 1 or ty<0 and -1 or 0),0)
		return v,v
	end
end

return Trajectory