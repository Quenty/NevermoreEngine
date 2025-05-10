--[=[
	Holds baseline constants for the Ragdoll

	:::tip
	Do not modify this file. Instead, do this to apply new reference values.

	```lua
	RagdollMotorLimitData.NECK_LIMITS:SetAttributes(character.UpperTorso.Neck, {
		UpperAngle = 30;
	})

	```
	:::

	@class RagdollMotorLimitData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeData = require("AdorneeData")
local Table = require("Table")

return Table.readonly({
	NECK_LIMITS = AdorneeData.new({
		UpperAngle = 45,
		TwistLowerAngle = -40,
		TwistUpperAngle = 40,
		FrictionTorque = 15,
		ReferenceGravity = 196.2,
		ReferenceMass = 1.0249234437943,
	}),

	WAIST_LIMITS = AdorneeData.new({
		UpperAngle = 20,
		TwistLowerAngle = -40,
		TwistUpperAngle = 20,
		FrictionTorque = 750,
		ReferenceGravity = 196.2,
		ReferenceMass = 2.861558675766,
	}),

	ANKLE_LIMITS = AdorneeData.new({
		UpperAngle = 10,
		TwistLowerAngle = -10,
		TwistUpperAngle = 10,
		FrictionTorque = 0.5,
		ReferenceGravity = 196.2,
		ReferenceMass = 0.43671694397926,
	}),

	ELBOW_LIMITS = AdorneeData.new({
		-- Elbow is basically a hinge; but allow some twist for Supination and Pronation
		UpperAngle = 20,
		TwistLowerAngle = 5,
		TwistUpperAngle = 120,
		FrictionTorque = 0.5,
		ReferenceGravity = 196.2,
		ReferenceMass = 0.70196455717087,
	}),

	WRIST_LIMITS = AdorneeData.new({
		UpperAngle = 30,
		TwistLowerAngle = -10,
		TwistUpperAngle = 10,
		FrictionTorque = 1,
		ReferenceGravity = 196.2,
		ReferenceMass = 0.69132566452026,
	}),

	KNEE_LIMITS = AdorneeData.new({
		UpperAngle = 5,
		TwistLowerAngle = -120,
		TwistUpperAngle = -5,
		FrictionTorque = 0.5,
		ReferenceGravity = 196.2,
		ReferenceMass = 0.65389388799667,
	}),

	SHOULDER_LIMITS = AdorneeData.new({
		UpperAngle = 110,
		TwistLowerAngle = -85,
		TwistUpperAngle = 85,
		FrictionTorque = 0.5,
		ReferenceGravity = 196.2,
		ReferenceMass = 0.90918225049973,
	}),

	HIP_LIMITS = AdorneeData.new({
		UpperAngle = 40,
		TwistLowerAngle = -5,
		TwistUpperAngle = 80,
		FrictionTorque = 0.5,
		ReferenceGravity = 196.2,
		ReferenceMass = 1.9175016880035,
	}),

	-- R6

	R6_NECK_LIMITS = AdorneeData.new({
		UpperAngle = 30,
		TwistLowerAngle = -40,
		TwistUpperAngle = 40,
		FrictionTorque = 0.5,
		ReferenceGravity = 196.2,
		ReferenceMass = 1.4,
	}),

	R6_SHOULDER_LIMITS = AdorneeData.new({
		UpperAngle = 110,
		TwistLowerAngle = -85,
		TwistUpperAngle = 85,
		FrictionTorque = 0.5,
		ReferenceGravity = 196.2,
		ReferenceMass = 1.4,
	}),

	R6_HIP_LIMITS = AdorneeData.new({
		UpperAngle = 40,
		TwistLowerAngle = -5,
		TwistUpperAngle = 80,
		FrictionTorque = 0.5,
		ReferenceGravity = 196.2,
		ReferenceMass = 1.4,
	}),
})
