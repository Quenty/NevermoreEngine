--!strict
--[=[
	Rotation model for gamepad controls that uses Roblox's curve smoothing and other components.

	@class GamepadRotateModel
]=]

local require = require(script.Parent.loader).load(script)

local AccelTween = require("AccelTween")
local BaseObject = require("BaseObject")
local CameraGamepadInputUtils = require("CameraGamepadInputUtils")
local ValueObject = require("ValueObject")

local GamepadRotateModel = setmetatable({}, BaseObject)
GamepadRotateModel.__index = GamepadRotateModel
GamepadRotateModel.ClassName = "GamepadRotateModel"

export type GamepadRotateModel = typeof(setmetatable(
	{} :: {
		_lastInputObject: InputObject?,
		_rampVelocityX: AccelTween.AccelTween,
		_rampVelocityY: AccelTween.AccelTween,
		IsRotating: ValueObject.ValueObject<boolean>,
	},
	{} :: typeof({ __index = GamepadRotateModel })
)) & BaseObject.BaseObject

--[=[
	Constructs a new GamepadRotateModel.
	@return GamepadRotateModel
]=]
function GamepadRotateModel.new(): GamepadRotateModel
	local self: GamepadRotateModel = setmetatable(BaseObject.new() :: any, GamepadRotateModel)

	self._rampVelocityX = AccelTween.new(25)
	self._rampVelocityY = AccelTween.new(25)

	self.IsRotating = self._maid:Add(ValueObject.new(false, "boolean"))

	return self
end

--[=[
	Sets the acceleration for the game rotate model. The higher the acceleration
	the more linear the gamepad rotate model feels.

	:::tip
	Set this to something high, like 2500, for an FPS. This makes control feel a lot better.
	:::

	@param acceleration number
]=]
function GamepadRotateModel.SetAcceleration(self: GamepadRotateModel, acceleration: number): ()
	assert(type(acceleration) == "number", "Bad acceleration")

	self._rampVelocityX.a = acceleration
	self._rampVelocityY.a = acceleration
end

--[=[
	Gets the delta for the thumbstick
	@return Vector2
]=]
function GamepadRotateModel.GetThumbstickDeltaAngle(self: GamepadRotateModel): Vector2
	if not self._lastInputObject then
		return Vector2.zero
	end

	return Vector2.new(self._rampVelocityX.p, self._rampVelocityY.p)
end

--[=[
	Stops rotation
]=]
function GamepadRotateModel.StopRotate(self: GamepadRotateModel): ()
	self._lastInputObject = nil
	self._rampVelocityX.t = 0
	self._rampVelocityX.p = self._rampVelocityX.t

	self._rampVelocityY.t = 0
	self._rampVelocityY.p = self._rampVelocityY.t

	self.IsRotating.Value = false
end

--[=[
	Converts the thumbstick input into a smoothed delta based upon deadzone and other
	components.

	@param inputObject InputObject
]=]
function GamepadRotateModel.HandleThumbstickInput(self: GamepadRotateModel, inputObject: InputObject): ()
	if CameraGamepadInputUtils.outOfDeadZone(inputObject) then
		self._lastInputObject = inputObject

		local stickOffset = Vector2.new(-inputObject.Position.X, inputObject.Position.Y) -- Invert axis!
		local adjustedStickOffset = CameraGamepadInputUtils.gamepadLinearToCurve(stickOffset)

		self._rampVelocityX.t = adjustedStickOffset.X
		self._rampVelocityY.t = adjustedStickOffset.Y

		self.IsRotating.Value = true
	else
		self:StopRotate()
	end
end

return GamepadRotateModel
