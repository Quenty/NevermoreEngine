--[=[
	Constants for the [Ragdoll] class.
	@class RagdollConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	IS_MOTOR_ANIMATED_ATTRIBUTE = "IsMotorAnimated";
	FRICTION_TORQUE_ATTRIBUTE = "RagdollFrictionTorque";
	RETURN_SPRING_SPEED_ATTRIBUTE = "RagdollSpringReturnSpeed";
})