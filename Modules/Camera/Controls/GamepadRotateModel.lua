---
-- @classmod GamepadRotateModel
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local AccelTween = require("AccelTween")

local GamepadRotateModel = {}
GamepadRotateModel.__index = GamepadRotateModel
GamepadRotateModel.ClassName = "GamepadRotateModel"

function GamepadRotateModel.new()
	local self = setmetatable({}, GamepadRotateModel)

	self.DEADZONE = 0.1
	self.SpeedMultiplier = Vector2.new(0.1, 0.1)

	self.RampVelocityX = AccelTween.new(5)
	self.RampVelocityY = AccelTween.new(5)

	self.IsRotating = Instance.new("BoolValue")
	self.IsRotating.Value = false

	return self
end

do
	-- See: https://github.com/Roblox/Core-Scripts/blob/cad3a477e39b93ecafdd610b1d8b89d239ab18e2/PlayerScripts/StarterPlayerScripts/CameraScript/RootCamera.lua#L395
	-- K is a tunable parameter that changes the shape of the S-curve
	-- the larger K is the more straight/linear the curve gets
	local k = 0.35
	local lowerK = 0.8
	function GamepadRotateModel:SCurveTranform(t)
		t = math.clamp(t, -1, 1)
		if t >= 0 then
			return (k*t) / (k - t + 1)
		end
		return -((lowerK*-t) / (lowerK + t + 1))
	end
end

function GamepadRotateModel:ToSCurveSpace(t)
	return (1 + self.DEADZONE) * (2*math.abs(t) - 1) - self.DEADZONE
end

function GamepadRotateModel:FromSCurveSpace(t)
	return t/2 + 0.5
end

function GamepadRotateModel:GamepadLinearToCurve(ThumbstickPosition)
	local function OnAxis(AxisValue)
		local Sign = math.sign(AxisValue)
		local Point = self:FromSCurveSpace(self:SCurveTranform(self:ToSCurveSpace(math.abs(AxisValue))))
		return math.clamp(Point * Sign, -1, 1)
	end
	return Vector2.new(OnAxis(ThumbstickPosition.x), OnAxis(ThumbstickPosition.y))
end

function GamepadRotateModel:OutOfDeadzone(inputObject)
	local StickOffset = inputObject.Position
	return StickOffset.magnitude >= self.DEADZONE
end

function GamepadRotateModel:GetThumbstickDeltaAngle()
	if not self._lastInputObject then
		return Vector2.new()
	end

	return Vector2.new(self.RampVelocityX.p, self.RampVelocityY.p)
end

function GamepadRotateModel:StopRotate()
	self._lastInputObject = nil
	self.RampVelocityX.t = 0
	self.RampVelocityX.p = self.RampVelocityX.t

	self.RampVelocityY.t = 0
	self.RampVelocityY.p = self.RampVelocityY.t

	self.IsRotating.Value = false
end

function GamepadRotateModel:HandleThumbstickInput(inputObject)
	local outOfDeadZone = self:OutOfDeadzone(inputObject)

	if outOfDeadZone then
		self._lastInputObject = inputObject


		local StickOffset = self._lastInputObject.Position
		StickOffset = Vector2.new(StickOffset.x, -StickOffset.y)  -- Invert axis!

		local AdjustedStickOffset = self:GamepadLinearToCurve(StickOffset)
		self.RampVelocityX.t = AdjustedStickOffset.x * self.SpeedMultiplier.x
		self.RampVelocityY.t = AdjustedStickOffset.y * self.SpeedMultiplier.y

		self.IsRotating.Value = true
	else
		self:StopRotate()
	end
end

return GamepadRotateModel