--!strict
--[=[
	Add another layer of effects that can be faded in/out
	@class FadeBetweenCamera3
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraFrame = require("CameraFrame")
local CameraState = require("CameraState")
local CubicSplineUtils = require("CubicSplineUtils")
local FieldOfViewUtils = require("FieldOfViewUtils")
local QFrame = require("QFrame")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")
local SummedCamera = require("SummedCamera")

local FadeBetweenCamera3 = {}
FadeBetweenCamera3.ClassName = "FadeBetweenCamera3"

export type FadeBetweenCamera3 = typeof(setmetatable(
	{} :: {
		_spring: Spring.Spring<number>,
		CameraA: CameraEffectUtils.CameraLike,
		CameraB: CameraEffectUtils.CameraLike,
		HasReachedTarget: boolean,
		Damper: number,
		Value: number,
		Speed: number,
		Velocity: number,
		Target: number,
		Epsilon: number?,
	},
	{} :: typeof({ __index = FadeBetweenCamera3 })
)) & CameraEffectUtils.CameraEffect

--[=[
	@param cameraA CameraLike
	@param cameraB CameraLike
	@return FadeBetweenCamera3
]=]
function FadeBetweenCamera3.new(
	cameraA: CameraEffectUtils.CameraLike,
	cameraB: CameraEffectUtils.CameraLike
): FadeBetweenCamera3
	local self: FadeBetweenCamera3 = setmetatable(
		{
			_spring = Spring.new(0),
			CameraA = cameraA or error("No cameraA"),
			CameraB = cameraB or error("No cameraB"),
		} :: any,
		FadeBetweenCamera3
	)

	self.Damper = 1
	self.Speed = 15

	return self
end

function FadeBetweenCamera3:__add(other)
	return SummedCamera.new(self, other)
end

function FadeBetweenCamera3:__newindex(index, value)
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
	elseif index == "CameraA" or index == "CameraB" or index == "Epsilon" then
		rawset(self, index, value)
	else
		error(string.format("%q is not a valid member of FadeBetweenCamera3", tostring(index)))
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within FadeBetweenCamera3
]=]
function FadeBetweenCamera3:__index(index)
	if index == "CameraState" then
		local _, t = SpringUtils.animating(self._spring, rawget(self, "Epsilon"))
		if t == 0 then
			return self.CameraStateA
		elseif t == 1 then
			return self.CameraStateB
		else
			local stateA = self.CameraStateA
			local stateB = self.CameraStateB

			local frameA = stateA.CameraFrame
			local frameB = stateB.CameraFrame

			local dist = (frameA.Position - frameB.Position).magnitude

			local node0 = CubicSplineUtils.newSplineNode(
				0,
				frameA.Position,
				stateA.CameraFrameDerivative.Position + frameA.CFrame.lookVector * dist * 0.3
			)
			local node1 = CubicSplineUtils.newSplineNode(
				1,
				frameB.Position,
				stateB.CameraFrameDerivative.Position + frameB.CFrame.lookVector * dist * 0.3
			)

			-- We do the position this way because 0^-1 is undefined
			--stateA.Position + (stateB.Position - stateA.Position)*t
			local newNode = CubicSplineUtils.tweenSplineNodes(node0, node1, t)
			local delta = (frameB * (frameA ^ -1))

			local deltaQFrame = delta.QFrame
			if deltaQFrame.W < 0 then
				delta.QFrame = QFrame.new(
					deltaQFrame.x,
					deltaQFrame.y,
					deltaQFrame.z,
					-deltaQFrame.W,
					-deltaQFrame.X,
					-deltaQFrame.Y,
					-deltaQFrame.Z
				)
			end

			local newState = delta ^ t * frameA
			newState.FieldOfView = FieldOfViewUtils.lerpInHeightSpace(frameA.FieldOfView, frameB.FieldOfView, t)
			newState.Position = newNode.p

			-- require("Draw").point(newState.Position)

			return CameraState.new(newState, CameraFrame.new(QFrame.fromVector3(newNode.v, QFrame.new())))
		end
	elseif index == "CameraStateA" then
		return self.CameraA.CameraState or self.CameraA
	elseif index == "CameraStateB" then
		return self.CameraB.CameraState or self.CameraB
	elseif index == "Damper" then
		return self._spring.Damper
	elseif index == "Value" then
		local _, t = SpringUtils.animating(self._spring, rawget(self, "Epsilon"))
		return t
	elseif index == "Speed" then
		return self._spring.Speed
	elseif index == "Target" then
		return self._spring.Target
	elseif index == "Velocity" then
		local animating = SpringUtils.animating(self._spring, rawget(self, "Epsilon"))
		if animating then
			return self._spring.Velocity
		else
			return 0
		end
	elseif index == "HasReachedTarget" then
		local animating = SpringUtils.animating(self._spring, rawget(self, "Epsilon"))
		return not animating
	elseif index == "Spring" then
		return self._spring
	elseif index == "Epsilon" then
		return rawget(self, "Epsilon")
	elseif FadeBetweenCamera3[index] then
		return FadeBetweenCamera3[index]
	else
		error(string.format("%q is not a valid member of FadeBetweenCamera3", tostring(index)))
	end
end

return FadeBetweenCamera3
