--- CFrame representation as a quaternion
-- @module QFrame

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Quaternion = require("Quaternion")

local QFrame = {}
QFrame.__index = QFrame

function QFrame.new(px, py, pz, w, x, y, z)
	local self = setmetatable({}, QFrame)
	self.px = px or 0
	self.py = py or 0
	self.pz = pz or 0
	self.w = w or 1
	self.x = x or 0
	self.y = y or 0
	self.z = z or 0

	return self
end

function QFrame.fromCFrameClosestTo(cframe, closestTo)
	local w, x, y, z = Quaternion.QuaternionFromCFrame(cframe)
	if not w then
		return nil
	end

	local dot = w*closestTo.w + x*closestTo.x + y*closestTo.y + z*closestTo.z

	if dot < 0 then
		return QFrame.new(cframe.x, cframe.y, cframe.z, -w, -x, -y, -z)
	end
	return QFrame.new(cframe.x, cframe.y, cframe.z, w, x, y, z)
end

function QFrame.toCFrame(self)
	local cframe = CFrame.new(self.px, self.py, self.pz, self.x, self.y, self.z, self.w)
	if cframe == cframe then
		return cframe
	else
		return nil
	end
end

function QFrame.toPosition(self)
	return Vector3.new(self.px, self.py, self.pz)
end

function QFrame.__add(a, b)
	assert(getmetatable(a) == QFrame and getmetatable(b) == QFrame,
		"QFrame + non-QFrame attempted")

	return QFrame.new(a.px + b.px, a.py + b.py, a.pz + b.pz, a.w + b.w, a.x + b.x, a.y + b.y, a.z + b.z)
end

function QFrame.__mul(a, b)
	if type(a) == "number" then
		return QFrame.new(a*b.px, a*b.py, a*b.pz, a*b.w, a*b.x, a*b.y, a*b.z)
	elseif type(b) == "number" then
		return QFrame.new(a.px*b, a.py*b, a.pz*b, a.w*b, a.x*b, a.y*b, a.z*b)
	else
		error("QFrame * non-QFrame attempted")
	end
end

return QFrame