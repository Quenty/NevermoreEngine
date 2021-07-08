---
-- @classmod CameraFrame
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local QFrame = require("QFrame")

local CameraFrame = {}
CameraFrame.ClassName = "CameraFrame"
CameraFrame.__index = CameraFrame

function CameraFrame.new(qFrame, fieldOfView)
	local self = setmetatable({}, CameraFrame)

	self.QFrame = qFrame or QFrame.new()
	self.FieldOfView = fieldOfView or 0

	return self
end

function CameraFrame.isCameraFrame(value)
	return getmetatable(value) == CameraFrame
end

function CameraFrame:__index(index)
	if index == "CFrame" then
		return QFrame.toCFrame(self.QFrame) or warn("[CameraFrame] - NaN")
	elseif index == "Position" then
		return QFrame.toPosition(self.QFrame) or warn("[CameraFrame] - NaN")
	elseif CameraFrame[index] then
		return CameraFrame[index]
	else
		error(("'%s' is not a valid index of CameraState"):format(tostring(index)))
	end
end

function CameraFrame:__newindex(index, value)
	if index == "CFrame" then
		assert(typeof(value) == "CFrame")

		local qFrame = QFrame.fromCFrameClosestTo(value, self.QFrame)
		assert(qFrame) -- Yikes if this fails, but it occurs

		rawset(self, "QFrame", qFrame)
	elseif index == "Position" then
		assert(typeof(value) == "Vector3")

		local q = self.QFrame
		rawset(self, "QFrame", QFrame.new(value.x, value.y, value.z, q.W, q.X, q.Y, q.Z))
	elseif index == "FieldOfView" or index == "QFrame" or index == "QFrameDerivative" then
		rawset(self, index, value)
	else
		error(("'%s' is not a valid index of CameraState"):format(tostring(index)))
	end
end

function CameraFrame.__add(a, b)
	assert(CameraFrame.isCameraFrame(a) and CameraFrame.isCameraFrame(b),
		"CameraFrame + non-CameraFrame attempted")

	return CameraFrame.new(a.QFrame + b.QFrame, a.FieldOfView + b.FieldOfView)
end

function CameraFrame.__sub(a, b)
	assert(CameraFrame.isCameraFrame(a) and CameraFrame.isCameraFrame(b),
		"CameraFrame - non-CameraFrame attempted")

	return CameraFrame.new(a.QFrame - b.QFrame, a.FieldOfView - b.FieldOfView)
end

function CameraFrame.__unm(a)
	return CameraFrame.new(-a.QFrame, -a.FieldOfView)
end

function CameraFrame.__mul(a, b)
	if type(a) == "number" and CameraFrame.isCameraFrame(b) then
		return CameraFrame.new(a*b.QFrame, a*b.FieldOfView)
	elseif CameraFrame.isCameraFrame(b) and type(b) == "number" then
		return CameraFrame.new(a.QFrame*b, a.FieldOfView*b)
	elseif CameraFrame.isCameraFrame(a) and CameraFrame.isCameraFrame(b) then
		return CameraFrame.new(a.QFrame*b.QFrame, a.FieldOfView*b.FieldOfView)
	else
		error("CameraFrame * non-CameraFrame attempted")
	end
end

function CameraFrame.__div(a, b)
	if CameraFrame.isCameraFrame(a) and type(b) == "number" then
		return CameraFrame.new(a.QFrame/b, a.FieldOfView/b)
	else
		error("CameraFrame * non-CameraFrame attempted")
	end
end

function CameraFrame.__pow(a, b)
	if CameraFrame.isCameraFrame(a) and type(b) == "number" then
		return CameraFrame.new(a.QFrame^b, a.FieldOfView^b)
	else
		error("CameraFrame ^ non-CameraFrame attempted")
	end
end

function CameraFrame.__eq(a, b)
	return a.QFrame == b.QFrame and a.FieldOfView == b.FieldOfView
end

return CameraFrame