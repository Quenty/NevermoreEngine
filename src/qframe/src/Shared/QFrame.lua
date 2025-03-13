--!strict
--[=[
	CFrame representation as a quaternion. Alternative representation of a [CFrame].
	@class QFrame
]=]

local QFrame = {}
QFrame.__index = QFrame

export type QFrame = typeof(setmetatable(
	{} :: {
		x: number,
		y: number,
		z: number,
		W: number,
		X: number,
		Y: number,
		Z: number,
	},
	QFrame
))

--[=[
	Constructs a new QFrame
	@return QFrame
]=]
function QFrame.new(x: number?, y: number?, z: number?, W: number?, X: number?, Y: number?, Z: number?): QFrame
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

--[=[
	Returns whether a value is a QFrame
	@param value any
	@return boolean
]=]
function QFrame.isQFrame(value: any): boolean
	return getmetatable(value) == QFrame
end

--[=[
	Gets the QFrame closest to that CFrame
	@param cframe CFrame
	@param closestTo QFrame
	@return QFrame
]=]
function QFrame.fromCFrameClosestTo(cframe: CFrame, closestTo: QFrame)
	assert(typeof(cframe) == "CFrame", "Bad cframe")
	assert(QFrame.isQFrame(closestTo), "Bad closestTo")

	local axis, angle = cframe:ToAxisAngle()
	local W = math.cos(angle / 2)
	local X = math.sin(angle / 2) * axis.X
	local Y = math.sin(angle / 2) * axis.Y
	local Z = math.sin(angle / 2) * axis.Z

	local dot = W * closestTo.W + X * closestTo.X + Y * closestTo.Y + Z * closestTo.Z

	if dot < 0 then
		return QFrame.new(cframe.X, cframe.Y, cframe.Z, -W, -X, -Y, -Z)
	end

	return QFrame.new(cframe.X, cframe.Y, cframe.Z, W, X, Y, Z)
end

--[=[
	Constructs a QFrame from a position and another QFrame rotation.
	@param vector Vector3
	@param qFrame QFrame
	@return QFrame
]=]
function QFrame.fromVector3(vector: Vector3, qFrame: QFrame): QFrame
	assert(typeof(vector) == "Vector3", "Bad vector")
	assert(QFrame.isQFrame(qFrame), "Bad qFrame")

	return QFrame.new(vector.X, vector.Y, vector.Z, qFrame.W, qFrame.X, qFrame.Y, qFrame.Z)
end

--[=[
	Converts the QFrame to a [CFrame]

	@param self QFrame
	@return CFrame?
]=]
function QFrame.toCFrame(self): CFrame?
	local cframe = CFrame.new(self.x, self.y, self.z, self.X, self.Y, self.Z, self.W)
	if cframe == cframe then
		return cframe
	else
		return nil
	end
end

--[=[
	Converts the QFrame to a [Vector3] position
	@param self QFrame
	@return Vector3
]=]
function QFrame.toPosition(self: QFrame): Vector3
	return Vector3.new(self.x, self.y, self.z)
end

--[=[
	Returns true if the QFrame contains a NaN value.
	@param a QFrame
	@return boolean
]=]
function QFrame.isNAN(a: QFrame): boolean
	return a.x ~= a.x or a.y ~= a.y or a.z ~= a.z or a.W ~= a.W or a.X ~= a.X or a.Y ~= a.Y or a.Z ~= a.Z
end

--[=[
	Inverts the QFrame
	@param a QFrame
	@return QFrame
]=]
function QFrame.__unm(a: QFrame): QFrame
	return QFrame.new(-a.x, -a.y, -a.z, -a.W, -a.X, -a.Y, -a.Z)
end

--[=[
	Adds the QFrames together
	@param a QFrame
	@param b QFrame
	@return QFrame
]=]
function QFrame.__add(a: QFrame, b: QFrame): QFrame
	assert(QFrame.isQFrame(a) and QFrame.isQFrame(b), "QFrame + non-QFrame attempted")

	return QFrame.new(a.x + b.x, a.y + b.y, a.z + b.z, a.W + b.W, a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

--[=[
	Subtracts the QFrames together
	@param a QFrame
	@param b QFrame
	@return QFrame
]=]
function QFrame.__sub(a: QFrame, b: QFrame): QFrame
	assert(QFrame.isQFrame(a) and QFrame.isQFrame(b), "QFrame - non-QFrame attempted")

	return QFrame.new(a.x - b.x, a.y - b.y, a.z - b.z, a.W - b.W, a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

--[=[
	Takes the QFrame to the power, using quaternion power formula.
	@param a QFrame
	@param b number
	@return QFrame
]=]
function QFrame.__pow(a: QFrame, b: number): QFrame
	assert(QFrame.isQFrame(a) and type(b) == "number", "Bad a or b")

	-- Center of mass agnostic power formula
	-- It will move an object in the same arc regardless of where it's center is
	-- O*(O^-1*B*O)^t*O^-1 = B^t

	local ax, ay, az = a.x, a.y, a.z
	local aW, aX, aY, aZ = a.W, a.X, a.Y, a.Z

	-- first let's power the quaternion
	local aMag = math.sqrt(aW * aW + aX * aX + aY * aY + aZ * aZ)
	local aIm = math.sqrt(aX * aX + aY * aY + aZ * aZ)
	local cMag = aMag ^ b

	if aIm <= 1e-8 * aMag then
		return QFrame.new(b * ax, b * ay, b * az, cMag, 0, 0, 0)
	end

	local rx = aX / aIm
	local ry = aY / aIm
	local rz = aZ / aIm

	local cAng = b * math.atan2(aIm, aW)
	local cCos = math.cos(cAng)
	local cSin = math.sin(cAng)

	local cW = cMag * cCos
	local cX = cMag * cSin * rx
	local cY = cMag * cSin * ry
	local cZ = cMag * cSin * rz

	-- now we power the position
	local k = ax * rx + ay * ry + az * rz
	local wx, wy, wz = k * rx, k * ry, k * rz
	local ux, uy, uz = ax - wx, ay - wy, az - wz
	local vx, vy, vz = ry * az - rz * ay, rz * ax - rx * az, rx * ay - ry * ax
	local re = cSin * (aW / aIm * cCos + cSin)
	local im = cSin * (aW / aIm * cSin - cCos)

	local cx = re * ux + im * vx + b * wx
	local cy = re * uy + im * vy + b * wy
	local cz = re * uz + im * vz + b * wz

	return QFrame.new(cx, cy, cz, cW, cX, cY, cZ)
end

--[=[
	Multiplies the QFrames together
	@param a QFrame | number
	@param b QFrame | number
	@return QFrame
]=]
function QFrame.__mul(a, b): QFrame
	if type(a) == "number" and QFrame.isQFrame(b) then
		return QFrame.new(a * b.x, a * b.y, a * b.z, a * b.W, a * b.X, a * b.Y, a * b.Z)
	elseif QFrame.isQFrame(a) and type(b) == "number" then
		return QFrame.new(a.x * b, a.y * b, a.z * b, a.W * b, a.X * b, a.Y * b, a.Z * b)
	elseif QFrame.isQFrame(a) and QFrame.isQFrame(b) then
		local A2 = a.W * a.W + a.X * a.X + a.Y * a.Y + a.Z * a.Z

		-- stylua: ignore
		return QFrame.new(
			a.x + ((a.W*a.W + a.X*a.X - a.Y*a.Y - a.Z*a.Z)*b.x + 2*(a.X*a.Y - a.W*a.Z)*b.y + 2*(a.W*a.Y + a.X*a.Z)*b.z)
				/A2,
			a.y + (2*(a.X*a.Y + a.W*a.Z)*b.x + (a.W*a.W - a.X*a.X + a.Y*a.Y - a.Z*a.Z)*b.y + 2*(a.Y*a.Z - a.W*a.X)*b.z)
				/A2,
			a.z + (2*(a.X*a.Z - a.W*a.Y)*b.x + 2*(a.W*a.X + a.Y*a.Z)*b.y + (a.W*a.W - a.X*a.X - a.Y*a.Y + a.Z*a.Z)*b.z)
				/A2,
			a.W*b.W - a.X*b.X - a.Y*b.Y - a.Z*b.Z,
			a.W*b.X + a.X*b.W + a.Y*b.Z - a.Z*b.Y,
			a.W*b.Y - a.X*b.Z + a.Y*b.W + a.Z*b.X,
			a.W*b.Z + a.X*b.Y - a.Y*b.X + a.Z*b.W)
	else
		error("QFrame * non-QFrame attempted")
	end
end

--[=[
	Divides the QFrame by the number
	@param a QFrame
	@param b number
	@return QFrame
]=]
function QFrame.__div(a: QFrame, b: number): QFrame
	if type(b) == "number" then
		return QFrame.new(a.x / b, a.y / b, a.z / b, a.W / b, a.X / b, a.Y / b, a.Z / b)
	else
		error("QFrame / non-QFrame attempted")
	end
end

--[=[
	Compares the QFrame for equality.
	@param a QFrame
	@param b QFrame
	@return boolean
]=]
function QFrame.__eq(a: QFrame, b: QFrame)
	return a.x == b.x and a.y == b.y and a.z == b.z and a.W == b.W and a.X == b.X and a.Y == b.Y and a.Z == b.Z
end

return QFrame
