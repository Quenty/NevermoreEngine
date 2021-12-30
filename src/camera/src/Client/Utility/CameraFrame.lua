--[=[
	Represents a camera state at a certain point. Can perform math on this state.
	@class CameraFrame
]=]

local require = require(script.Parent.loader).load(script)

local QFrame = require("QFrame")

local CameraFrame = {}
CameraFrame.ClassName = "CameraFrame"
CameraFrame.__index = CameraFrame

--[=[
	Constructs a new CameraFrame
	@param qFrame QFrame
	@param fieldOfView number
	@return CameraFrame
]=]
function CameraFrame.new(qFrame, fieldOfView)
	local self = setmetatable({}, CameraFrame)

	self.QFrame = qFrame or QFrame.new()
	self.FieldOfView = fieldOfView or 0

	return self
end

--[=[
	Returns whether a value is a CameraFrame
	@param value any
	@return boolean
]=]
function CameraFrame.isCameraFrame(value)
	return getmetatable(value) == CameraFrame
end

--[=[
	@prop CFrame CFrame
	@within CameraFrame
]=]

--[=[
	@prop Position Vector3
	@within CameraFrame
]=]

--[=[
	@prop FieldOfView number
	@within CameraFrame
]=]

--[=[
	@prop QFrame QFrame
	@within CameraFrame
]=]

--[=[
	@prop QFrame QFrame
	@within CameraFrame
]=]

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
		assert(typeof(value) == "CFrame", "Bad value")

		local qFrame = QFrame.fromCFrameClosestTo(value, self.QFrame)
		assert(qFrame, "Failed to convert") -- Yikes if this fails, but it occurs

		rawset(self, "QFrame", qFrame)
	elseif index == "Position" then
		assert(typeof(value) == "Vector3", "Bad value")

		local q = self.QFrame
		rawset(self, "QFrame", QFrame.new(value.x, value.y, value.z, q.W, q.X, q.Y, q.Z))
	elseif index == "FieldOfView" or index == "QFrame" then
		rawset(self, index, value)
	else
		error(("'%s' is not a valid index of CameraState"):format(tostring(index)))
	end
end

--[=[
	Linearly adds the camera frames together.
	@param a CameraFrame
	@param b CameraFrame
	@return CameraFrame
]=]
function CameraFrame.__add(a, b)
	assert(CameraFrame.isCameraFrame(a) and CameraFrame.isCameraFrame(b),
		"CameraFrame + non-CameraFrame attempted")

	return CameraFrame.new(a.QFrame + b.QFrame, a.FieldOfView + b.FieldOfView)
end

--[=[
	Linearly subtractions the camera frames together.
	@param a CameraFrame
	@param b CameraFrame
	@return CameraFrame
]=]
function CameraFrame.__sub(a, b)
	assert(CameraFrame.isCameraFrame(a) and CameraFrame.isCameraFrame(b),
		"CameraFrame - non-CameraFrame attempted")

	return CameraFrame.new(a.QFrame - b.QFrame, a.FieldOfView - b.FieldOfView)
end

--[=[
	Inverts the QFrame and the field of view.
	@param a CameraFrame
	@return CameraFrame
]=]
function CameraFrame.__unm(a)
	return CameraFrame.new(-a.QFrame, -a.FieldOfView)
end

--[=[
	Multiplies the camera frame with the given value
	@param a CameraFrame | number
	@param b CameraFrame | number
	@return CameraFrame
]=]
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

--[=[
	Divides the camera frame by the value
	@param a CameraFrame
	@param b number
	@return CameraFrame
]=]
function CameraFrame.__div(a, b)
	if CameraFrame.isCameraFrame(a) and type(b) == "number" then
		return CameraFrame.new(a.QFrame/b, a.FieldOfView/b)
	else
		error("CameraFrame * non-CameraFrame attempted")
	end
end

--[=[
	Takes the camera frame to the Nth power
	@param a CameraFrame
	@param b number
	@return CameraFrame
]=]
function CameraFrame.__pow(a, b)
	if CameraFrame.isCameraFrame(a) and type(b) == "number" then
		return CameraFrame.new(a.QFrame^b, a.FieldOfView^b)
	else
		error("CameraFrame ^ non-CameraFrame attempted")
	end
end

--[=[
	Compares the camera frame to make sure they're equal
	@param a CameraFrame
	@param b CameraFrame
	@return boolean
]=]
function CameraFrame.__eq(a, b)
	return a.QFrame == b.QFrame and a.FieldOfView == b.FieldOfView
end

return CameraFrame