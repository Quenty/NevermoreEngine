-- Optimized CFrame interpolator module ~ by Stravant
-- Based off of code by Treyreynolds posted on the Roblox Developer Forum

local fromAxisAngle = CFrame.fromAxisAngle
local components = CFrame.new().components
local inverse = CFrame.new().inverse
local v3 = Vector3.new
local acos = math.acos
local sqrt = math.sqrt
local invroot2 = 1/math.sqrt(2)

return function(c0, c1) -- (CFrame from, CFrame to) -> (float theta, (float fraction -> CFrame between))
	-- The expanded matrix
	local _, _, _, xx, yx, zx, 
	               xy, yy, zy, 
	               xz, yz, zz = components(inverse(c0)*c1)
	
	-- The cos-theta of the axisAngles from 
	local cosTheta = (xx + yy + zz - 1)/2
	
	-- Rotation axis
	local rotationAxis = v3(yz-zy, zx-xz, xy-yx)
	
	-- The position to tween through
	local positionDelta = (c1.p - c0.p)
		
	-- Theta
	local theta;			
		
	-- Catch degenerate cases
	if cosTheta >= 0.999 then
		-- Case same rotation, just return an interpolator over the positions
		return 0, function(t)
			return c0 + positionDelta*t
		end	
	elseif cosTheta <= -0.999 then
		-- Case exactly opposite rotations, disambiguate
		theta = math.pi
		xx = (xx + 1) / 2
		yy = (yy + 1) / 2
		zz = (zz + 1) / 2
		if xx > yy and xx > zz then
			if xx < 0.001 then
				rotationAxis = v3(0, invroot2, invroot2)
			else
				local x = sqrt(xx)
				xy = (xy + yx) / 4
				xz = (xz + zx) / 4
				rotationAxis = v3(x, xy/x, xz/x)
			end
		elseif yy > zz then
			if yy < 0.001 then
				rotationAxis = v3(invroot2, 0, invroot2)
			else
				local y = sqrt(yy)
				xy = (xy + yx) / 4
				yz = (yz + zy) / 4
				rotationAxis = v3(xy/y, y, yz/y)
			end	
		else
			if zz < 0.001 then
				rotationAxis = v3(invroot2, invroot2, 0)
			else
				local z = sqrt(zz)
				xz = (xz + zx) / 4
				yz = (yz + zy) / 4
				rotationAxis = v3(xz/z, yz/z, z)
			end
		end
	else
		-- Normal case, get theta from cosTheta
		theta = acos(cosTheta)
	end
	
	-- Return the interpolator
	return theta, function(t)
		return c0*fromAxisAngle(rotationAxis, theta*t) + positionDelta*t
	end
end