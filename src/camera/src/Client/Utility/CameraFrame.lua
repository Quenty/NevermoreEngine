--!strict
--[=[
	Represents a camera state at a certain point. Can perform math on this state.
	@class CameraFrame
]=]

local require = require(script.Parent.loader).load(script)

local DuckTypeUtils = require("DuckTypeUtils")
local QFrame = require("QFrame")

local CameraFrame = {}
CameraFrame.ClassName = "CameraFrame"
CameraFrame.__index = CameraFrame

export type CameraFrame = typeof(setmetatable(
	{} :: {
		--[=[
			@prop CFrame CFrame
			@within CameraFrame
		]=]
		CFrame: CFrame,

		--[=[
			@prop Position Vector3
			@within CameraFrame
		]=]
		Position: Vector3,

		--[=[
			@prop FieldOfView number
			@within CameraFrame
		]=]
		FieldOfView: number,

		--[=[
			@prop QFrame QFrame
			@within CameraFrame
		]=]
		QFrame: QFrame.QFrame,
	},
	{} :: typeof({ __index = CameraFrame })
))

--[=[
	Constructs a new CameraFrame
	@param qFrame QFrame
	@param fieldOfView number
	@return CameraFrame
]=]
function CameraFrame.new(qFrame: QFrame.QFrame?, fieldOfView: number?): CameraFrame
	local self: CameraFrame = setmetatable({} :: any, CameraFrame)

	self.QFrame = qFrame or QFrame.new()
	self.FieldOfView = fieldOfView or 0

	return self
end

--[=[
	Returns whether a value is a CameraFrame
	@param value any
	@return boolean
]=]
function CameraFrame.isCameraFrame(value: any): boolean
	return DuckTypeUtils.isImplementation(CameraFrame, value)
end

(CameraFrame :: any).__index = function(self, index): any
	if index == "CFrame" then
		local result = QFrame.toCFrame(self.QFrame)
		if not result then
			warn("[CameraFrame.CFrame] - NaN in QFrame")
			return CFrame.new()
		end
		return result
	elseif index == "Position" then
		local result = QFrame.toPosition(self.QFrame)
		if not result then
			warn("[CameraFrame.Position] - NaN in QFrame")
			return Vector3.zero
		end
		return result
	elseif CameraFrame[index] then
		return CameraFrame[index]
	else
		error(string.format("'%s' is not a valid index of CameraState", tostring(index)))
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
		rawset(self, "QFrame", QFrame.new(value.X, value.Y, value.Z, q.W, q.X, q.Y, q.Z))
	elseif index == "FieldOfView" or index == "QFrame" then
		rawset(self, index, value)
	else
		error(string.format("'%s' is not a valid index of CameraState", tostring(index)))
	end
end

--[=[
	Linearly adds the camera frames together.
	@param a CameraFrame
	@param b CameraFrame
	@return CameraFrame
]=]
function CameraFrame.__add(a: CameraFrame, b: CameraFrame): CameraFrame
	assert(CameraFrame.isCameraFrame(a) and CameraFrame.isCameraFrame(b), "CameraFrame + non-CameraFrame attempted")

	return CameraFrame.new(a.QFrame + b.QFrame, a.FieldOfView + b.FieldOfView)
end

--[=[
	Linearly subtractions the camera frames together.
	@param a CameraFrame
	@param b CameraFrame
	@return CameraFrame
]=]
function CameraFrame.__sub(a: CameraFrame, b: CameraFrame): CameraFrame
	assert(CameraFrame.isCameraFrame(a) and CameraFrame.isCameraFrame(b), "CameraFrame - non-CameraFrame attempted")

	return CameraFrame.new(a.QFrame - b.QFrame, a.FieldOfView - b.FieldOfView)
end

--[=[
	Inverts the QFrame and the field of view.
	@param a CameraFrame
	@return CameraFrame
]=]
function CameraFrame.__unm(a: CameraFrame): CameraFrame
	return CameraFrame.new(-a.QFrame, -a.FieldOfView)
end

--[=[
	Multiplies the camera frame with the given value
	@param a CameraFrame | number
	@param b CameraFrame | number
	@return CameraFrame
]=]
function CameraFrame.__mul(a: CameraFrame | number, b: CameraFrame | number): CameraFrame
	if type(a) == "number" and CameraFrame.isCameraFrame(b) then
		return CameraFrame.new(a * (b :: CameraFrame).QFrame, a * (b :: CameraFrame).FieldOfView)
	elseif CameraFrame.isCameraFrame(b) and type(b) == "number" then
		return CameraFrame.new((a :: CameraFrame).QFrame * b, (a :: CameraFrame).FieldOfView * b)
	elseif CameraFrame.isCameraFrame(a) and CameraFrame.isCameraFrame(b) then
		return CameraFrame.new((a :: CameraFrame).QFrame * b.QFrame, (a :: CameraFrame).FieldOfView * b.FieldOfView)
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
function CameraFrame.__div(a: CameraFrame, b: CameraFrame): CameraFrame
	if CameraFrame.isCameraFrame(a) and type(b) == "number" then
		return CameraFrame.new(a.QFrame / b, a.FieldOfView / b)
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
function CameraFrame.__pow(a: CameraFrame, b: number): CameraFrame
	if CameraFrame.isCameraFrame(a) and type(b) == "number" then
		return CameraFrame.new(a.QFrame ^ b, a.FieldOfView ^ b)
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
function CameraFrame.__eq(a: CameraFrame, b: CameraFrame): boolean
	return a.QFrame == b.QFrame and a.FieldOfView == b.FieldOfView
end

return CameraFrame
