--[=[
	@class FadeBetweenCamera2
]=]

local require = require(script.Parent.loader).load(script)

local CameraState = require("CameraState")
local CubicSplineUtils = require("CubicSplineUtils")

local FadeBetweenCamera2 = {}
FadeBetweenCamera2.ClassName = "FadeBetweenCamera2"
FadeBetweenCamera2.__index = FadeBetweenCamera2

--[=[
	@param cameraA CameraLike
	@param cameraB CameraLike
	@return FadeBetweenCamera2
]=]
function FadeBetweenCamera2.new(cameraA, cameraB)
	local self = setmetatable({
		CameraA = cameraA or error("No cameraA"),
		CameraB = cameraB or error("No cameraB"),
		_state0 = cameraA.CameraState,
		_time0 = os.clock(),
		_target = 0,
		_position0 = 0,
		_speed = 15,
	}, FadeBetweenCamera2)

	return self
end

function FadeBetweenCamera2:__newindex(index, value)
	if index == "Value" then
		assert(type(value) == "number", "Bad value")

		if self._position0 ~= value then
			local now = os.clock()
			self._state0, self._position0 = self:_computeCameraState(value)
			self._time0 = now
		end
	elseif index == "Target" then
		assert(type(value) == "number", "Bad value")
		if self._target ~= value then
			local now = os.clock()
			self._state0, self._position0 = self:_computeCameraState(self:_computeDoneProportion(now))
			self._time0 = now
			self._target = value
		end
	elseif index == "Speed" then
		assert(type(value) == "number", "Bad value")

		if self._speed ~= value then
			local now = os.clock()
			self._state0, self._position0 = self:_computeCameraState(self:_computeDoneProportion(now))
			self._time0 = now
			self._speed = value
		end
	elseif index == "CameraA" or index == "CameraB" then
		local now = os.clock()
		self._state0, self._position0 = self:_computeCameraState(self:_computeDoneProportion(now))
		self._time0 = now
		rawset(self, index, value)
	else
		error(string.format("%q is not a valid member of FadeBetweenCamera2", tostring(index)))
	end
end

--[=[
	The current state.
	@readonly
	@prop CameraState CameraState
	@within FadeBetweenCamera2
]=]
function FadeBetweenCamera2:__index(index)
	if index == "CameraState" then
		local state, _ = self:_computeCameraState(self:_computeDoneProportion(os.clock()))
		return state
	elseif index == "Value" then
		return self:_computeDoneProportion(os.clock())
	elseif index == "Target" then
		return self._target
	elseif index == "HasReachedTarget" then
		return self:_computeDoneProportion(os.clock()) >= 1
	elseif index == "Speed" then
		return self._speed
	elseif index == "Velocity" then
		return self._speed
	elseif FadeBetweenCamera2[index] then
		return FadeBetweenCamera2[index]
	else
		error(string.format("%q is not a valid member of FadeBetweenCamera2", tostring(index)))
	end
end

function FadeBetweenCamera2:_computeTargetState()
	if self._target == 0 then
		return self.CameraA.CameraState
	elseif self._target == 1 then
		return self.CameraB.CameraState
	else
		-- Perform initial interpolation to get target (uncommon requirement)
		local a = self.CameraA.CameraState
		local b = self.CameraB.CameraState

		local node0 = CubicSplineUtils.newSplineNode(0, a.CameraFrame, a.CameraFrameDerivative)
		local node1 = CubicSplineUtils.newSplineNode(1, b.CameraFrame, b.CameraFrameDerivative)
		local newNode = CubicSplineUtils.tweenSplineNodes(node0, node1, self._target)

		return CameraState.new(newNode.p, newNode.v)
	end
end

function FadeBetweenCamera2:_computeCameraState(t)
	if t <= 0 then
		return self._state0, 0
	end

	if t >= 1 then
		return self:_computeTargetState(), 1
	else
		local a = self._state0
		local b = self:_computeTargetState()

		local node0 = CubicSplineUtils.newSplineNode(0, a.CameraFrame, a.CameraFrameDerivative)
		local node1 = CubicSplineUtils.newSplineNode(1, b.CameraFrame, b.CameraFrameDerivative)

		local newNode = CubicSplineUtils.tweenSplineNodes(node0, node1, t)

		local newState = CameraState.new(newNode.p, newNode.v)
		return newState, t
	end
end

function FadeBetweenCamera2:_computeDoneProportion(now)
	local dist_to_travel = math.abs(self._position0 - self._target)
	if dist_to_travel == 0 then
		return 1
	end

	local SPEED_CONSTANT = 0.5 / 15 -- 0.5 seconds is 15 speed in the other system

	return math.clamp(self._speed * (now - self._time0) * SPEED_CONSTANT / dist_to_travel, 0, 1)
end

return FadeBetweenCamera2
