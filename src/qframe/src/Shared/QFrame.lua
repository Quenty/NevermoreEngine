--- CFrame representation as a quaternion
-- @module QFrame

local QFrame = {}
QFrame.__index = QFrame

function QFrame.new(x, y, z, W, X, Y, Z)
	local self = setmetatable({}, QFrame)
	self.x = x or 0
	self.y = y or 0
	self.z = z or 0
	self.W = W or 1
	self.X = X or 0
	self.Y = Y or 0
	self.Z = Z or 0

	return self
end

function QFrame.isQFrame(value)
	return getmetatable(value) == QFrame
end

function QFrame.fromCFrameClosestTo(cframe, closestTo)
	assert(typeof(cframe) == "CFrame")
	assert(QFrame.isQFrame(closestTo))

	local axis, angle = cframe:toAxisAngle()
	local W = math.cos(angle/2)
	local X = math.sin(angle/2)*axis.x
	local Y = math.sin(angle/2)*axis.y
	local Z = math.sin(angle/2)*axis.z

	local dot = W*closestTo.W + X*closestTo.X + Y*closestTo.Y + Z*closestTo.Z

	if dot < 0 then
		return QFrame.new(cframe.x, cframe.y, cframe.z, -W, -X, -Y, -Z)
	end

	return QFrame.new(cframe.x, cframe.y, cframe.z, W, X, Y, Z)
end

function QFrame.fromVector3(vector, qFrame)
	assert(typeof(vector) == "Vector3")
	assert(QFrame.isQFrame(qFrame))

	return QFrame.new(vector.x, vector.y, vector.z, qFrame.W, qFrame.X, qFrame.Y, qFrame.Z)
end

function QFrame.toCFrame(self)
	local cframe = CFrame.new(self.x, self.y, self.z, self.X, self.Y, self.Z, self.W)
	if cframe == cframe then
		return cframe
	else
		return nil
	end
end

function QFrame.toPosition(self)
	return Vector3.new(self.x, self.y, self.z)
end

function QFrame.isNAN(a)
	return a.x == a.x and a.y == a.y and a.z == a.z
		and a.W == a.W and a.X == a.X and a.Y == a.Y and a.Z == a.Z
end

function QFrame.__unm(a)
	return QFrame.new(-a.x, -a.y, -a.z, -a.W, -a.X, -a.Y, -a.Z)
end

function QFrame.__add(a, b)
	assert(QFrame.isQFrame(a) and QFrame.isQFrame(b),
		"QFrame + non-QFrame attempted")

	return QFrame.new(a.x + b.x, a.y + b.y, a.z + b.z, a.W + b.W, a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

function QFrame.__sub(a, b)
	assert(QFrame.isQFrame(a) and QFrame.isQFrame(b),
		"QFrame - non-QFrame attempted")

	return QFrame.new(a.x - b.x, a.y - b.y, a.z - b.z, a.W - b.W, a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

function QFrame.__pow(a, b)
	assert(QFrame.isQFrame(a) and type(b) == "number")

	local w, x, y, z = a.W, a.X, a.Y, a.Z
	local vv = x*x + y*y + z*z

	if vv > 0 then
		local v = math.sqrt(vv)
		local m = (w*w+vv)^(b/2)
		local theta = b*math.atan2(v,w)
		local s = m*math.sin(theta)/v
		return QFrame.new(a.x^b, a.y^b, a.z^b, m*math.cos(theta), x*s, y*s, z*s)
	else
		if w < 0 then
			local m = (-w)^b
			local s = m*math.sin(math.pi*b)*0.57735026918962576450914878050196--3^-0.5
			return QFrame.new(a.x^b, a.y^b, a.z^b, m*math.cos(math.pi*b), s, s, s)
		else
			return QFrame.new(a.x^b, a.y^b, a.z^b, w^b, 0, 0, 0)
		end
	end
end

function QFrame.__mul(a, b)
	if type(a) == "number" and QFrame.isQFrame(b) then
		return QFrame.new(a*b.x, a*b.y, a*b.z, a*b.W, a*b.X, a*b.Y, a*b.Z)
	elseif QFrame.isQFrame(a) and type(b) == "number" then
		return QFrame.new(a.x*b, a.y*b, a.z*b, a.W*b, a.X*b, a.Y*b, a.Z*b)
	elseif QFrame.isQFrame(a) and QFrame.isQFrame(b) then
		return QFrame.new(
			a.x*b.x,
			a.y*b.y,
			a.z*b.z,
			a.W*b.W - a.X*b.X - a.Y*b.Y - a.Z*b.Z,
			a.W*b.X + a.X*b.W + a.Y*b.Z - a.Z*b.Y,
			a.W*b.Y - a.X*b.Z + a.Y*b.W + a.Z*b.X,
			a.W*b.Z + a.X*b.Y - a.Y*b.X + a.Z*b.W)
	else
		error("QFrame * non-QFrame attempted")
	end
end

function QFrame.__div(a, b)
	if type(b) == "number" then
		return QFrame.new(a.x/b, a.y/b, a.z/b, a.W/b, a.X/b, a.Y/b, a.Z/b)
	else
		error("QFrame / non-QFrame attempted")
	end
end

function QFrame.__eq(a, b)
	return a.x == b.x and a.y == b.y and a.z == b.z
		and a.W == b.W and a.X == b.X and a.Y == b.Y and a.Z == b.Z
end

return QFrame