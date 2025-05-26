--[=[
	Instead of modifying this file, consider setting attributes on each motor on humanoid
	join.

	@class RagdollBallSocketUtils
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local EnumUtils = require("EnumUtils")
local Maid = require("Maid")
local RagdollMotorLimitData = require("RagdollMotorLimitData")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxPhysicsUtils = require("RxPhysicsUtils")
local RxR15Utils = require("RxR15Utils")

local RagdollBallSocketUtils = {}

local R6_RAGDOLL_RIG = {
	{
		part0Name = "Torso",
		part1Name = "Head",
		attachmentName = "NeckAttachment",
		motorParentName = "Torso",
		motorName = "Neck",
		limitData = RagdollMotorLimitData.R6_NECK_LIMITS,
	},
	{
		part0Name = "Torso",
		part1Name = "Left Leg",
		attachmentName = "LeftHipAttachment",
		motorParentName = "Torso",
		motorName = "Left Hip",
		limitData = RagdollMotorLimitData.R6_HIP_LIMITS,
	},
	{
		part0Name = "Torso",
		part1Name = "Right Leg",
		attachmentName = "RightHipAttachment",
		motorParentName = "Torso",
		motorName = "Right Hip",
		limitData = RagdollMotorLimitData.R6_HIP_LIMITS,
	},
	{
		part0Name = "Torso",
		part1Name = "Left Arm",
		attachmentName = "LeftShoulderRagdollAttachment",
		motorParentName = "Torso",
		motorName = "Left Shoulder",
		limitData = RagdollMotorLimitData.R6_SHOULDER_LIMITS,
	},
	{
		part0Name = "Torso",
		part1Name = "Right Arm",
		attachmentName = "RightShoulderRagdollAttachment",
		motorParentName = "Torso",
		motorName = "Right Shoulder",
		limitData = RagdollMotorLimitData.R6_SHOULDER_LIMITS,
	},
}

local R15_RAGDOLL_RIG = {
	{
		part0Name = "UpperTorso",
		part1Name = "Head",
		attachmentName = "NeckRigAttachment",
		motorParentName = "Head",
		motorName = "Neck",
		limitData = RagdollMotorLimitData.NECK_LIMITS,
	},
	{
		part0Name = "LowerTorso",
		part1Name = "UpperTorso",
		attachmentName = "WaistRigAttachment",
		motorParentName = "UpperTorso",
		motorName = "Waist",
		limitData = RagdollMotorLimitData.WAIST_LIMITS,
	},
	{
		part0Name = "UpperTorso",
		part1Name = "LeftUpperArm",
		attachmentName = "LeftShoulderRagdollAttachment",
		motorParentName = "LeftUpperArm",
		motorName = "LeftShoulder",
		limitData = RagdollMotorLimitData.SHOULDER_LIMITS,
	},
	{
		part0Name = "LeftUpperArm",
		part1Name = "LeftLowerArm",
		attachmentName = "LeftElbowRigAttachment",
		motorParentName = "LeftLowerArm",
		motorName = "LeftElbow",
		limitData = RagdollMotorLimitData.ELBOW_LIMITS,
	},
	{
		part0Name = "LeftLowerArm",
		part1Name = "LeftHand",
		attachmentName = "LeftWristRigAttachment",
		motorParentName = "LeftHand",
		motorName = "LeftWrist",
		limitData = RagdollMotorLimitData.WRIST_LIMITS,
	},
	{
		part0Name = "UpperTorso",
		part1Name = "RightUpperArm",
		attachmentName = "RightShoulderRagdollAttachment",
		motorParentName = "RightUpperArm",
		motorName = "RightShoulder",
		limitData = RagdollMotorLimitData.SHOULDER_LIMITS,
	},
	{
		part0Name = "RightUpperArm",
		part1Name = "RightLowerArm",
		attachmentName = "RightElbowRigAttachment",
		motorParentName = "RightLowerArm",
		motorName = "RightElbow",
		limitData = RagdollMotorLimitData.ELBOW_LIMITS,
	},
	{
		part0Name = "RightLowerArm",
		part1Name = "RightHand",
		attachmentName = "RightWristRigAttachment",
		motorParentName = "RightHand",
		motorName = "RightWrist",
		limitData = RagdollMotorLimitData.WRIST_LIMITS,
	},

	{
		part0Name = "LowerTorso",
		part1Name = "LeftUpperLeg",
		attachmentName = "LeftHipRigAttachment",
		motorParentName = "LeftUpperLeg",
		motorName = "LeftHip",
		limitData = RagdollMotorLimitData.HIP_LIMITS,
	},
	{
		part0Name = "LeftUpperLeg",
		part1Name = "LeftLowerLeg",
		attachmentName = "LeftKneeRigAttachment",
		motorParentName = "LeftLowerLeg",
		motorName = "LeftKnee",
		limitData = RagdollMotorLimitData.KNEE_LIMITS,
	},
	{
		part0Name = "LeftLowerLeg",
		part1Name = "LeftFoot",
		attachmentName = "LeftAnkleRigAttachment",
		motorParentName = "LeftFoot",
		motorName = "LeftAnkle",
		limitData = RagdollMotorLimitData.ANKLE_LIMITS,
	},

	{
		part0Name = "LowerTorso",
		part1Name = "RightUpperLeg",
		attachmentName = "RightHipRigAttachment",
		motorParentName = "RightUpperLeg",
		motorName = "RightHip",
		limitData = RagdollMotorLimitData.HIP_LIMITS,
	},
	{
		part0Name = "RightUpperLeg",
		part1Name = "RightLowerLeg",
		attachmentName = "RightKneeRigAttachment",
		motorParentName = "RightLowerLeg",
		motorName = "RightKnee",
		limitData = RagdollMotorLimitData.KNEE_LIMITS,
	},
	{
		part0Name = "RightLowerLeg",
		part1Name = "RightFoot",
		attachmentName = "RightAnkleRigAttachment",
		motorParentName = "RightFoot",
		motorName = "RightAnkle",
		limitData = RagdollMotorLimitData.ANKLE_LIMITS,
	},
}

function RagdollBallSocketUtils.getRigData(rigType)
	if rigType == Enum.HumanoidRigType.R15 then
		return R15_RAGDOLL_RIG
	elseif rigType == Enum.HumanoidRigType.R6 then
		return R6_RAGDOLL_RIG
	else
		error(string.format("[RagdollBallSocketUtils] - Unknown rigType %q", tostring(rigType)))
	end
end

function RagdollBallSocketUtils.ensureBallSockets(character, rigType)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")
	assert(EnumUtils.isOfType(Enum.HumanoidRigType, rigType), "Bad rigType")

	local topMaid = Maid.new()

	for _, data in RagdollBallSocketUtils.getRigData(rigType) do
		local part0Name = assert(data.part0Name, "No part0Name")
		local part1Name = assert(data.part1Name, "No part1Name")
		local motorName = assert(data.motorName, "No motorName")
		local attachmentName = assert(data.attachmentName, "No attachmentName")
		local limitData = assert(data.limitData, "No limits")

		local observable = RxR15Utils.observeRigMotorBrio(character, data.motorParentName, motorName):Pipe({
			RxBrioUtils.switchMapBrio(function(motor)
				if motor then
					return RxBrioUtils.flatCombineLatest({
						motor = Rx.of(motor),
						part1 = RxR15Utils.observeCharacterPartBrio(character, part1Name),
						attachment0 = RxR15Utils.observeRigAttachmentBrio(character, part0Name, attachmentName),
						attachment1 = RxR15Utils.observeRigAttachmentBrio(character, part1Name, attachmentName),
						limitData = Rx.of(limitData),
					})
				else
					return Rx.of({})
				end
			end),
			RxBrioUtils.where(function(motorState)
				return motorState.attachment0
						and motorState.attachment1
						and motorState.part1
						and motorState.motor
						and true
					or false
			end),
		})

		topMaid:GiveTask(observable:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid, motorState = brio:ToMaidAndValue()
			local limitValue = motorState.limitData:CreateAdorneeDataValue(motorState.motor)

			local ballSocket = maid:Add(Instance.new("BallSocketConstraint"))
			ballSocket.Name = "RagdollBallSocket"
			ballSocket.Enabled = true
			ballSocket.LimitsEnabled = true
			ballSocket.UpperAngle = limitValue.UpperAngle.Value
			ballSocket.TwistLimitsEnabled = true
			ballSocket.TwistLowerAngle = limitValue.TwistLowerAngle.Value
			ballSocket.TwistUpperAngle = limitValue.TwistUpperAngle.Value
			ballSocket.Attachment0 = motorState.attachment0
			ballSocket.Attachment1 = motorState.attachment1

			maid:GiveTask(limitValue.UpperAngle:Observe():Subscribe(function(value)
				ballSocket.UpperAngle = value
			end))
			maid:GiveTask(limitValue.TwistLowerAngle:Observe():Subscribe(function(value)
				ballSocket.TwistLowerAngle = value
			end))
			maid:GiveTask(limitValue.TwistUpperAngle:Observe():Subscribe(function(value)
				ballSocket.TwistUpperAngle = value
			end))

			maid:GiveTask(Rx.combineLatest({
				frictionTorque = limitValue.FrictionTorque:Observe(),
				referenceGravity = limitValue.ReferenceGravity:Observe(),
				referenceMass = limitValue.ReferenceMass:Observe(),
				gravity = RxInstanceUtils.observeProperty(Workspace, "Gravity"),
				mass = RxPhysicsUtils.observePartMass(motorState.part1),
			}):Subscribe(function(state)
				local gravityScale = state.gravity / state.referenceGravity
				local referenceMass = state.referenceMass
				local massScale = referenceMass and (state.mass / referenceMass) or 1
				ballSocket.MaxFrictionTorque = state.frictionTorque * massScale * gravityScale
			end))

			ballSocket.Parent = motorState.part1
		end))
	end

	return topMaid
end

return RagdollBallSocketUtils
