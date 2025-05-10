--[=[
	Add another layer of effects that can be faded in/out
	@class FadeBetweenCamera
]=]

local require = require(script.Parent.loader).load(script)

local CameraState = require("CameraState")
local CubicSplineUtils = require("CubicSplineUtils")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")
local SummedCamera = require("SummedCamera")

local FadeBetweenCamera = {}
FadeBetweenCamera.ClassName = "FadeBetweenCamera"

--[=[
	@param cameraA CameraLike
	@param cameraB CameraLike
	@return FadeBetweenCamera
]=]
function FadeBetweenCamera.new(cameraA, cameraB)
	local self = setmetatable({
		_spring = Spring.new(0),
		CameraA = cameraA or error("No cameraA"),
		CameraB = cameraB or error("No cameraB"),
	}, FadeBetweenCamera)

	self.Damper = 1
	self.Speed = 15

	return self
end

function FadeBetweenCamera:__add(other)
	return SummedCamera.new(self, other)
end

function FadeBetweenCamera:__newindex(index, value)
	if index == "Damper" then
		self._spring.Damper = value
	elseif index == "Value" then
		self._spring.Value = value
	elseif index == "Speed" then
		self._spring.Speed = value
	elseif index == "Target" then
		self._spring.Target = value
	elseif index == "Velocity" then
		self._spring.Velocity = value
	elseif index == "CameraA" or index == "CameraB" then
		rawset(self, index, value)
	else
		error(string.format("%q is not a valid member of FadeBetweenCamera", tostring(index)))
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within FadeBetweenCamera
]=]
function FadeBetweenCamera:__index(index)
	if index == "CameraState" then
		local _, t = SpringUtils.animating(self._spring)
		if t <= 0 then
			return self.CameraStateA
		elseif t >= 1 then
			return self.CameraStateB
		else
			local a = self.CameraStateA
			local b = self.CameraStateB
			--[[
			-- We do the position this way because 0^-1 is undefined
			local linear = a.Position + (b.Position - a.Position)*t
			local delta = (b*(a^-1))

			local deltaQFrame = delta.QFrame
			if deltaQFrame.W < 0 then
				delta.QFrame = QFrame.new(
					deltaQFrame.x, deltaQFrame.y, deltaQFrame.z, deltaQFrame.W, deltaQFrame.X, deltaQFrame.Y, deltaQFrame.Z)
			end

			local newState = delta^t*a
			newState.FieldOfView = FieldOfViewUtils.lerpInHeightSpace(a.FieldOfView, b.FieldOfView, t)
			newState.Position = linear

			return newState
			--]]
			local node0 = CubicSplineUtils.newSplineNode(0, a.CameraFrame, a.CameraFrameDerivative)
			local node1 = CubicSplineUtils.newSplineNode(1, b.CameraFrame, b.CameraFrameDerivative)

			local newNode = CubicSplineUtils.tweenSplineNodes(node0, node1, t)

			local newState = CameraState.new(newNode.p, newNode.v)
			return newState
		end
	elseif index == "CameraStateA" then
		return self.CameraA.CameraState or self.CameraA
	elseif index == "CameraStateB" then
		return self.CameraB.CameraState or self.CameraB
	elseif index == "Damper" then
		return self._spring.Damper
	elseif index == "Value" then
		local _, t = SpringUtils.animating(self._spring)
		return t
	elseif index == "Speed" then
		return self._spring.Speed
	elseif index == "Target" then
		return self._spring.Target
	elseif index == "Velocity" then
		local animating = SpringUtils.animating(self._spring)
		if animating then
			return self._spring.Velocity
		else
			return Vector3.zero
		end
	elseif index == "HasReachedTarget" then
		local animating = SpringUtils.animating(self._spring)
		return not animating
	elseif index == "Spring" then
		return self._spring
	elseif FadeBetweenCamera[index] then
		return FadeBetweenCamera[index]
	else
		error(string.format("%q is not a valid member of FadeBetweenCamera", tostring(index)))
	end
end

return FadeBetweenCamera
