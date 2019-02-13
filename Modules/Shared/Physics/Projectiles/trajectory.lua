--- Utility function for estimating low and high arcs of projectiles. Solves for bullet
-- drop given

--- Returns two possible paths from origin to target where the magnitude of the initial velocity is initialVelocity
-- @tparam Vector3 origin Origin the the bullet
-- @tparam Vector3 target Target for the bullet
-- @tparam number initialVelocity Magnitude of the initial velocity
-- @tparam number gravityForce Force of the gravity
-- @treturn[opt] vector3 lowTrajectory Initial velocity for a low trajectory arc
-- @treturn[opt] vector3 highTrajectory Initial velocity for a high trajectory arc
-- @treturn[opt] vector3 fallbackTrajectory Trajectory directly at target as afallback
return function(origin, target, initialVelocity, gravityForce)
	local g = -gravityForce
	local ox,oy,oz=origin.x,origin.y,origin.z
	local rx,rz=target.x-ox,target.z-oz
	local tx2=rx*rx+rz*rz
	local ty=target.y-oy
	if tx2>0 then
		local v2=initialVelocity*initialVelocity

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
			return nil, nil, Vector3.new(rx, (tx2^0.5), rz).unit * initialVelocity
		end
	else
		local v=Vector3.new(0,initialVelocity*(ty>0 and 1 or ty<0 and -1 or 0),0)
		return v,v
	end
end