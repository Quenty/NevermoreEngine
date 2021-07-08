---
-- @classmod FABRIKConstraint

local PI2 = math.pi/2
local PI4 = math.pi/4

--

local FABRIKConstraint = {}
FABRIKConstraint.__index = FABRIKConstraint

--

local function inEllipse(p, a, b)
	return ((p.x*p.x) / (a*a)) + ((p.y*p.y) / (b*b)) <= 1
end

local function constrainEllipse(isInEllipse, p, a, b)
	local px, py = math.abs(p.x), math.abs(p.y)
	local t = isInEllipse and math.atan2(py, px) or PI4
	local x, y

	for _ = 1, 4 do
		local ct, st = math.cos(t), math.sin(t)

		x, y = a*ct, b*st
		local ex = (a*a - b*b) * ct*ct*ct / a
		local ey = (b*b - a*a) * st*st*st / b

		local rx, ry = x - ex, y - ey
		local qx, qy = px - ex, py - ey
		local r = math.sqrt(rx*rx + ry*ry)
		local q = math.sqrt(qx*qx + qy*qy)

		local delta_c = r*math.asin((rx*qy - ry*qx)/(r*q))
		local delta_t = delta_c / math.sqrt(a*a + b*b - x*x - y*y)

		t = t + delta_t
		t = math.clamp(t, 0, PI2)
	end

	return Vector3.new(math.sign(p.x)*x, math.sign(p.y)*y, p.z)
end

--

function FABRIKConstraint.new(left, right, up, down, twistLeft, twistRight)
	local self = setmetatable({}, FABRIKConstraint)

	self.Left = math.pi*2 - left
	self.Right = math.pi*2 - right
	self.Up = up
	self.Down = down

	return self
end

--

function FABRIKConstraint:Constrain(lpoint, length)
	local z = length
	local w = z * (lpoint.x >= 0 and math.cos(self.Right) or math.cos(self.Left))
	local h = z * (lpoint.y >= 0 and math.sin(self.Up) or math.sin(self.Down))
	local isInEllipse = inEllipse(lpoint, w, h)

	if (lpoint.z >= 0) then
		local x, y, _ = lpoint.x, lpoint.y, -lpoint.z
		if (x == 0 and y == 0) then
			return Vector3.new(0, h, z)
		else
			lpoint = Vector3.new(x, y, z)
		end
	elseif (isInEllipse) then
		return lpoint
	end

	return constrainEllipse(isInEllipse, lpoint, w, h).Unit * length
end

--

return FABRIKConstraint