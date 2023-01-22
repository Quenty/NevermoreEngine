--[=[
	Constants for the [Ragdoll] class.
	@class RagdollConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	IS_MOTOR_ANIMATED_ATTRIBUTE = "IsMotorAnimated";
	RETURN_SPRING_SPEED_ATTRIBUTE = "RagdollSpringReturnSpeed";
	FRICTION_TORQUE_ATTRIBUTE = "RagdollFrictionTorque";
	UPPER_ANGLE_ATTRIBUTE = "RagdollUpperAngle";
	TWIST_LOWER_ANGLE_ATTRIBUTE = "RagdollTwistLowerAngle";
	TWIST_UPPER_ANGLE_ATTRIBUTE = "RagdollTwistUpperAngle";
})