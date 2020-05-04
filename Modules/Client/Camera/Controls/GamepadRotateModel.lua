--- Rotation model for gamepad controls
-- @classmod GamepadRotateModel

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local AccelTween = require("AccelTween")
local BaseObject = require("BaseObject")
local CameraGamepadInputUtils = require("CameraGamepadInputUtils")

local GamepadRotateModel = setmetatable({}, BaseObject)
GamepadRotateModel.__index = GamepadRotateModel
GamepadRotateModel.ClassName = "GamepadRotateModel"

function GamepadRotateModel.new()
	local self = setmetatable(BaseObject.new(), GamepadRotateModel)

	self._rampVelocityX = AccelTween.new(25)
	self._rampVelocityY = AccelTween.new(25)

	self.IsRotating = Instance.new("BoolValue")
	self.IsRotating.Value = false
	self._maid:GiveTask(self.IsRotating)

	return self
end

function GamepadRotateModel:GetThumbstickDeltaAngle()
	if not self._lastInputObject then
		return Vector2.new()
	end

	return Vector2.new(self._rampVelocityX.p, self._rampVelocityY.p)
end

function GamepadRotateModel:StopRotate()
	self._lastInputObject = nil
	self._rampVelocityX.t = 0
	self._rampVelocityX.p = self._rampVelocityX.t

	self._rampVelocityY.t = 0
	self._rampVelocityY.p = self._rampVelocityY.t

	self.IsRotating.Value = false
end

function GamepadRotateModel:HandleThumbstickInput(inputObject)
	if CameraGamepadInputUtils.outOfDeadZone(inputObject) then
		self._lastInputObject = inputObject

		local stickOffset = self._lastInputObject.Position
		stickOffset = Vector2.new(-stickOffset.x, stickOffset.y)  -- Invert axis!

		local adjustedStickOffset = CameraGamepadInputUtils.gamepadLinearToCurve(stickOffset)
		self._rampVelocityX.t = adjustedStickOffset.x
		self._rampVelocityY.t = adjustedStickOffset.y

		self.IsRotating.Value = true
	else
		self:StopRotate()
	end
end

return GamepadRotateModel