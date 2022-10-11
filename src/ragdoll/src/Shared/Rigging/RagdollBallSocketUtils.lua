--[=[
	Instead of modifying this file, consider setting attributes on each motor on humanoid
	join.

	@class RagdollBallSocketUtils
]=]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local RagdollConstants = require("RagdollConstants")
local RxAttributeUtils = require("RxAttributeUtils")
local AttributeUtils = require("AttributeUtils")
local RxR15Utils = require("RxR15Utils")
local EnumUtils = require("EnumUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local Maid = require("Maid")

local RagdollBallSocketUtils = {}

local REFERENCE_GRAVITY = 196.2 -- Gravity that joint friction values were tuned under.

local HEAD_LIMITS = {
	UpperAngle = 45,
	TwistLowerAngle = -40,
	TwistUpperAngle = 40,
	FrictionTorque = 400,
	ReferenceMass = 1.0249234437943,
}

local WAIST_LIMITS = {
	UpperAngle = 20,
	TwistLowerAngle = -40,
	TwistUpperAngle = 20,
	FrictionTorque = 750,
	ReferenceMass = 2.861558675766,
}

local ANKLE_LIMITS = {
	UpperAngle = 10,
	TwistLowerAngle = -10,
	TwistUpperAngle = 10,
	FrictionTorque = 0.5;
	ReferenceMass = 0.43671694397926,
}

local ELBOW_LIMITS = {
	-- Elbow is basically a hinge, but allow some twist for Supination and Pronation
	UpperAngle = 20,
	TwistLowerAngle = 5,
	TwistUpperAngle = 120,
	FrictionTorque = 0.5;
	ReferenceMass = 0.70196455717087,
}

local WRIST_LIMITS = {
	UpperAngle = 30,
	TwistLowerAngle = -10,
	TwistUpperAngle = 10,
	FrictionTorque = 1;
	ReferenceMass = 0.69132566452026,
}

local KNEE_LIMITS = {
	UpperAngle = 5,
	TwistLowerAngle = -120,
	TwistUpperAngle = -5,
	FrictionTorque = 0.5;
	ReferenceMass = 0.65389388799667,
}

local SHOULDER_LIMITS = {
	UpperAngle = 110,
	TwistLowerAngle = -85,
	TwistUpperAngle = 85,
	FrictionTorque = 0.5,
	ReferenceMass = 0.90918225049973,
}

local HIP_LIMITS = {
	UpperAngle = 40,
	TwistLowerAngle = -5,
	TwistUpperAngle = 80,
	FrictionTorque = 0.5,
	ReferenceMass = 1.9175016880035,
}

local R6_HEAD_LIMITS = {
	UpperAngle = 30,
	TwistLowerAngle = -40,
	TwistUpperAngle = 40,
	FrictionTorque = 0.5;
}

local R6_SHOULDER_LIMITS = {
	UpperAngle = 110,
	TwistLowerAngle = -85,
	TwistUpperAngle = 85,
	FrictionTorque = 0.5;
}

local R6_HIP_LIMITS = {
	UpperAngle = 40,
	TwistLowerAngle = -5,
	TwistUpperAngle = 80,
	FrictionTorque = 0.5;
}

local R6_RAGDOLL_RIG = {
	{
		part0Name = "Torso";
		part1Name ="Head",
		attachmentName = "NeckAttachment";
		motorParentName = "Torso";
		motorName = "Neck";
		limits = R6_HEAD_LIMITS;
	};
	{
		part0Name = "Torso";
		part1Name ="Left Leg";
		attachmentName = "LeftHipAttachment";
		motorParentName = "Torso";
		motorName = "Left Hip";
		limits = R6_HIP_LIMITS;
	};
	{
		part0Name = "Torso";
		part1Name ="Right Leg";
		attachmentName = "RightHipAttachment";
		motorParentName = "Torso";
		motorName = "Right Hip";
		limits = R6_HIP_LIMITS;
	};
	{
		part0Name = "Torso";
		part1Name ="Left Arm";
		attachmentName = "LeftShoulderRagdollAttachment";
		motorParentName = "Torso";
		motorName = "Left Shoulder";
		limits = R6_SHOULDER_LIMITS;
	};
	{
		part0Name = "Torso";
		part1Name ="Right Arm";
		attachmentName = "RightShoulderRagdollAttachment";
		motorParentName = "Torso";
		motorName = "Right Shoulder";
		limits = R6_SHOULDER_LIMITS;
	};
}

local R15_RAGDOLL_RIG = {
	{
		part0Name = "UpperTorso";
		part1Name = "Head";
		attachmentName = "NeckRigAttachment";
		motorParentName = "Head";
		motorName = "Neck";
		limits = HEAD_LIMITS;
	};
	{
		part0Name = "LowerTorso";
		part1Name = "UpperTorso";
		attachmentName = "WaistRigAttachment";
		motorParentName = "UpperTorso";
		motorName = "Waist";
		limits = WAIST_LIMITS;
	};
	{
		part0Name = "UpperTorso";
		part1Name = "LeftUpperArm";
		attachmentName = "LeftShoulderRagdollAttachment";
		motorParentName = "LeftUpperArm";
		motorName = "LeftShoulder";
		limits = SHOULDER_LIMITS;
	};
	{
		part0Name = "LeftUpperArm";
		part1Name = "LeftLowerArm";
		attachmentName = "LeftElbowRigAttachment";
		motorParentName = "LeftLowerArm";
		motorName = "LeftElbow";
		limits = ELBOW_LIMITS;
	};
	{
		part0Name = "LeftLowerArm";
		part1Name = "LeftHand";
		attachmentName = "LeftWristRigAttachment";
		motorParentName = "LeftHand";
		motorName = "LeftWrist";
		limits = WRIST_LIMITS;
	};
	{
		part0Name = "UpperTorso";
		part1Name = "RightUpperArm";
		attachmentName = "RightShoulderRagdollAttachment";
		motorParentName = "RightUpperArm";
		motorName = "RightShoulder";
		limits = SHOULDER_LIMITS;
	};
	{
		part0Name = "RightUpperArm";
		part1Name = "RightLowerArm";
		attachmentName = "RightElbowRigAttachment";
		motorParentName = "RightLowerArm";
		motorName = "RightElbow";
		limits = ELBOW_LIMITS;
	};
	{
		part0Name = "RightLowerArm";
		part1Name = "RightHand";
		attachmentName = "RightWristRigAttachment";
		motorParentName = "RightHand";
		motorName = "RightWrist";
		limits = WRIST_LIMITS;
	};

	{
		part0Name = "LowerTorso";
		part1Name = "LeftUpperLeg";
		attachmentName = "LeftHipRigAttachment";
		motorParentName = "LeftUpperLeg";
		motorName = "LeftHip";
		limits = HIP_LIMITS;
	};
	{
		part0Name = "LeftUpperLeg";
		part1Name = "LeftLowerLeg";
		attachmentName = "LeftKneeRigAttachment";
		motorParentName = "LeftLowerLeg";
		motorName = "LeftKnee";
		limits = KNEE_LIMITS;
	};
	{
		part0Name = "LeftLowerLeg";
		part1Name = "LeftFoot";
		attachmentName = "LeftAnkleRigAttachment";
		motorParentName = "LeftFoot";
		motorName = "LeftAnkle";
		limits = ANKLE_LIMITS;
	};

	{
		part0Name = "LowerTorso";
		part1Name = "RightUpperLeg";
		attachmentName = "RightHipRigAttachment";
		motorParentName = "RightUpperLeg";
		motorName = "RightHip";
		limits = HIP_LIMITS;
	};
	{
		part0Name = "RightUpperLeg";
		part1Name = "RightLowerLeg";
		attachmentName = "RightKneeRigAttachment";
		motorParentName = "RightLowerLeg";
		motorName = "RightKnee";
		limits = KNEE_LIMITS;
	};
	{
		part0Name = "RightLowerLeg";
		part1Name = "RightFoot";
		attachmentName = "RightAnkleRigAttachment";
		motorParentName = "RightFoot";
		motorName = "RightAnkle";
		limits = ANKLE_LIMITS;
	};
}

function RagdollBallSocketUtils.getRigData(rigType)
	if rigType == Enum.HumanoidRigType.R15 then
		return R15_RAGDOLL_RIG
	elseif rigType == Enum.HumanoidRigType.R6 then
		return R6_RAGDOLL_RIG
	else
		error(("[RagdollBallSocketUtils] - Unknown rigType %q"):format(tostring(rigType)))
	end
end

function RagdollBallSocketUtils.ensureBallSockets(character, rigType)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")
	assert(EnumUtils.isOfType(Enum.HumanoidRigType, rigType), "Bad rigType")

	local topMaid = Maid.new()

	for _, data in pairs(RagdollBallSocketUtils.getRigData(rigType)) do
		local part0Name = assert(data.part0Name, "No part0Name")
		local part1Name = assert(data.part1Name, "No part1Name")
		local motorName = assert(data.motorName, "No motorName")
		local attachmentName = assert(data.attachmentName, "No attachmentName")
		local limits = assert(data.limits, "No limits")

		local observable = RxBrioUtils.flatCombineLatest({
			motor = RxR15Utils.observeRigMotorBrio(character, data.motorParentName, motorName);
			part1 = RxR15Utils.observeCharacterPartBrio(character, part1Name);
			attachment0 = RxR15Utils.observeRigAttachmentBrio(character, part0Name, attachmentName);
			attachment1 = RxR15Utils.observeRigAttachmentBrio(character, part1Name, attachmentName);
			gravity = RxInstanceUtils.observeProperty(Workspace, "Gravity");
		})

		topMaid:GiveTask(observable:Subscribe(function(state)
			if state.attachment0 and state.attachment1 and state.part1 and state.motor then
				local maid = Maid.new()

				local ballSocket = Instance.new("BallSocketConstraint")
				ballSocket.Name = "RagdollBallSocket"
				ballSocket.Enabled = true
				ballSocket.LimitsEnabled = true
				ballSocket.UpperAngle = limits.UpperAngle
				ballSocket.TwistLimitsEnabled = true
				ballSocket.TwistLowerAngle = limits.TwistLowerAngle
				ballSocket.TwistUpperAngle = limits.TwistUpperAngle
				ballSocket.Attachment0 = state.attachment0
				ballSocket.Attachment1 = state.attachment1

				local default = assert(limits.FrictionTorque, "No FrictionTorque")

				-- Easier debugging
				AttributeUtils.initAttribute(state.motor, RagdollConstants.FRICTION_TORQUE_ATTRIBUTE, default)

				maid:GiveTask(RxAttributeUtils.observeAttribute(state.motor, RagdollConstants.FRICTION_TORQUE_ATTRIBUTE, default)
					:Subscribe(function(torque)
						local gravityScale = state.gravity / REFERENCE_GRAVITY
						local referenceMass = limits.ReferenceMass
						local massScale = referenceMass and (state.part1:GetMass() / referenceMass) or 1
						ballSocket.MaxFrictionTorque = torque * massScale * gravityScale
					end))

				ballSocket.Parent = state.part1
				maid:GiveTask(ballSocket)

				topMaid[data] = maid
			else
				topMaid[data] = nil
			end
		end))
	end

	return topMaid
end


return RagdollBallSocketUtils