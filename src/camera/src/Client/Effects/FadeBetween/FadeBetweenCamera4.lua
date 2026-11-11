--!strict
--[=[
	@class FadeBetweenCamera4
]=]

local require = require(script.Parent.loader).load(script)

local CameraEffectUtils = require("CameraEffectUtils")
local CameraState = require("CameraState")
local CubicSplineUtils = require("CubicSplineUtils")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")

local FadeBetweenCamera4 = {}
FadeBetweenCamera4.ClassName = "FadeBetweenCamera4"

export type FadeBetweenCamera4 =
	typeof(setmetatable(
		{} :: {
			CameraA: CameraEffectUtils.CameraEffect,
			CameraB: CameraEffectUtils.CameraEffect,
			_spring: Spring.Spring<number>,
			_position0: number,
			_state0: CameraState.CameraState,
			CameraState: CameraState.CameraState,
			Value: number,
			Target: number,
			HasReachedTarget: boolean,
			Speed: number,
			Velocity: number,
		},
		{} :: typeof({ __index = FadeBetweenCamera4 })
	))
	& CameraEffectUtils.CameraEffect

--[=[
	@param cameraA CameraLike
	@param cameraB CameraLike
	@return FadeBetweenCamera4
]=]
function FadeBetweenCamera4.new(
	cameraA: CameraEffectUtils.CameraEffect,
	cameraB: CameraEffectUtils.CameraEffect
): FadeBetweenCamera4
	local self: FadeBetweenCamera4 = setmetatable(
		{
			CameraA = cameraA or error("No cameraA"),
			CameraB = cameraB or error("No cameraB"),
			_spring = Spring.new(0),
			_position0 = 0,
			_state0 = cameraA.CameraState,
		} :: any,
		FadeBetweenCamera4
	)

	self._spring.s = 15

	return self
end

function FadeBetweenCamera4.__newindex(self: FadeBetweenCamera4, index, value)
	if index == "Value" then
		assert(type(value) == "number", "Bad value")

		local _, position = SpringUtils.animating(self._spring)
		self._state0, self._position0 = self:_computeCameraState(position)
		self._spring.p = value
	elseif index == "Target" then
		assert(type(value) == "number", "Bad value")

		local _, position = SpringUtils.animating(self._spring)
		self._state0, self._position0 = self:_computeCameraState(position)
		self._spring.t = value
	elseif index == "Speed" then
		assert(type(value) == "number", "Bad value")

		local _, position = SpringUtils.animating(self._spring)
		self._state0, self._position0 = self:_computeCameraState(position)
		self._spring.s = value
	elseif index == "CameraA" or index == "CameraB" then
		assert(type(value) ~= "nil", "Bad value")

		local _, position = SpringUtils.animating(self._spring)
		self._state0, self._position0 = self:_computeCameraState(position)
		rawset(self :: any, index, value)
	else
		error(string.format("%q is not a valid member of FadeBetweenCamera4", tostring(index)))
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within FadeBetweenCamera4
]=]
function FadeBetweenCamera4.__index(self: FadeBetweenCamera4, index)
	if index == "CameraState" then
		local _, value = SpringUtils.animating(self._spring)
		local state, _ = self:_computeCameraState(value)
		return state
	elseif index == "Value" then
		local _, value = SpringUtils.animating(self._spring)
		return value
	elseif index == "Target" then
		return self._spring.t
	elseif index == "HasReachedTarget" then
		local animating, _ = SpringUtils.animating(self._spring)
		return animating
	elseif index == "Speed" then
		return self._spring.s
	elseif index == "Velocity" then
		return self._spring.v
	elseif FadeBetweenCamera4[index] then
		return FadeBetweenCamera4[index]
	else
		error(string.format("%q is not a valid member of FadeBetweenCamera4", tostring(index)))
	end
end

function FadeBetweenCamera4._computeTargetState(self: FadeBetweenCamera4, target: number): CameraState.CameraState
	if target <= 0 then
		return self.CameraA.CameraState
	elseif target >= 1 then
		return self.CameraB.CameraState
	else
		-- Perform initial interpolation to get target (uncommon requirement)
		local a = self.CameraA.CameraState
		local b = self.CameraB.CameraState

		local node0 = CubicSplineUtils.newSplineNode(0, a.CameraFrame, a.CameraFrameDerivative)
		local node1 = CubicSplineUtils.newSplineNode(1, b.CameraFrame, b.CameraFrameDerivative)
		local newNode = CubicSplineUtils.tweenSplineNodes(node0, node1, self._spring.t)

		return CameraState.new(newNode.p, newNode.v)
	end
end

function FadeBetweenCamera4._computeCameraState(
	self: FadeBetweenCamera4,
	position: number
): (CameraState.CameraState, number)
	if position <= 0 then
		return self:_computeTargetState(0), 0
	elseif position >= 1 then
		return self:_computeTargetState(1), 1
	end

	local node0, node1
	if position < self._position0 then -- assume target is also moving in this direction
		local a = self:_computeTargetState(0)

		node0 = CubicSplineUtils.newSplineNode(0, a.CameraFrame, a.CameraFrameDerivative)
		node1 = CubicSplineUtils.newSplineNode(
			self._position0,
			self._state0.CameraFrame,
			self._state0.CameraFrameDerivative
		)
	else
		local b = self:_computeTargetState(1)

		node0 = CubicSplineUtils.newSplineNode(
			self._position0,
			self._state0.CameraFrame,
			self._state0.CameraFrameDerivative
		)
		node1 = CubicSplineUtils.newSplineNode(1, b.CameraFrame, b.CameraFrameDerivative)
	end

	local newNode = CubicSplineUtils.tweenSplineNodes(node0, node1, position)

	local newState = CameraState.new(newNode.p, newNode.v)
	return newState, position
end

return FadeBetweenCamera4
