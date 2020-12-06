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

function QFrame.fromCFrameClosestTo(cframe, closestTo)
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
	assert(getmetatable(a) == QFrame and getmetatable(b) == QFrame,
		"QFrame + non-QFrame attempted")

	return QFrame.new(a.x + b.x, a.y + b.y, a.z + b.z, a.W + b.W, a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

function QFrame.__sub(a, b)
	assert(getmetatable(a) == QFrame and getmetatable(b) == QFrame,
		"QFrame - non-QFrame attempted")

	return QFrame.new(a.x - b.x, a.y - b.y, a.z - b.z, a.W - b.W, a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

function QFrame.__mul(a, b)
	if type(a) == "number" then
		return QFrame.new(a*b.x, a*b.y, a*b.z, a*b.W, a*b.X, a*b.Y, a*b.Z)
	elseif type(b) == "number" then
		return QFrame.new(a.x*b, a.y*b, a.z*b, a.W*b, a.X*b, a.Y*b, a.Z*b)
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
	error("Use isNAN")
end

return QFrame