--- Rig types and data for ragdolling R15
-- @module RagdollRigtypes

local RagdollRigtypes = {}

local HEAD_LIMITS = {
	UpperAngle = 60;
	TwistLowerAngle = -60;
	TwistUpperAngle = 60;
}

local LOWER_TORSO_LIMITS = {
	UpperAngle = 5;
	TwistLowerAngle = -30;
	TwistUpperAngle = 175;
}

local HAND_FOOT_LIMITS = {
	UpperAngle = 15;
	TwistLowerAngle = -5;
	TwistUpperAngle = 5;
}

local ELBOW_LIMITS = {
	UpperAngle = 5;
	TwistLowerAngle = 0;
	TwistUpperAngle = 120;
}

local KNEE_LIMITS = {
	UpperAngle = 5;
	TwistLowerAngle = -120;
	TwistUpperAngle = 0;
}

local SHOULDER_LIMITS = {
	UpperAngle = 120;
	TwistLowerAngle = -60;
	TwistUpperAngle = 175;
}

local HIP_LIMITS = {
	UpperAngle = 60;
	TwistLowerAngle = -5;
	TwistUpperAngle = 90;
}

local R6_HEAD_LIMITS = {
	UpperAngle = 30;
	TwistLowerAngle = -60;
	TwistUpperAngle = 60;
}

local R6_SHOULDER_LIMITS = {
	UpperAngle = 90;
	TwistLowerAngle = -30;
	TwistUpperAngle = 175;
}

local R6_HIP_LIMITS = {
	UpperAngle = 60;
	TwistLowerAngle = -5;
	TwistUpperAngle = 120;
}


local function createJointData(attach0, attach1, limits)
	assert(attach0)
	assert(attach1)
	assert(limits)
	assert(limits.UpperAngle >= 0)
	assert(limits.TwistLowerAngle <= limits.TwistUpperAngle)

	return {
		attachment0 = attach0,
		attachment1 = attach1,
		limits = limits
	}
end

local function find(model)
	return function(first, second, limits)
		local part0 = model:FindFirstChild(first[1])
		local part1 = model:FindFirstChild(second[1])
		if part0 and part1 then
			local attach0 = part0:FindFirstChild(first[2])
			local attach1 = part1:FindFirstChild(second[2])
			if attach0 and attach1 and attach0:IsA("Attachment") and attach1:IsA("Attachment") then
				return createJointData(attach0, attach1, limits)
			end
		end
	end
end

function RagdollRigtypes.getNoCollisions(model, rigType)
	if rigType == Enum.HumanoidRigType.R6 then
		return RagdollRigtypes.getR6NoCollisions(model)
	elseif rigType == Enum.HumanoidRigType.R15 then
		return RagdollRigtypes.getR15NoCollisions(model)
	else
		warn("[RagdollRigtypes.getAttachments] - UnknownRigType")
		return {}
	end
end

-- Get list of attachments to make ballsocketconstraints between:
function RagdollRigtypes.getAttachments(model, rigType)
	if rigType == Enum.HumanoidRigType.R6 then
		return RagdollRigtypes.getR6Attachments(model)
	elseif rigType == Enum.HumanoidRigType.R15 then
		return RagdollRigtypes.getR15Attachments(model)
	else
		warn("[RagdollRigtypes.getAttachments] - UnknownRigType")
		return {}
	end
end

function RagdollRigtypes.getR6Attachments(model)
	local rightLegAttachment = Instance.new("Attachment")
	rightLegAttachment.Name = "RagdollRightLegAttachment"
	rightLegAttachment.Position = Vector3.new(0, 1, 0)
	rightLegAttachment.Parent = model:FindFirstChild("Right Leg")

	local leftLegAttachment = Instance.new("Attachment")
	leftLegAttachment.Name = "RagdollLeftLegAttachment"
	leftLegAttachment.Position = Vector3.new(0, 1, 0)
	leftLegAttachment.Parent = model:FindFirstChild("Left Leg")

	local torsoLeftAttachment = Instance.new("Attachment")
	torsoLeftAttachment.Name = "RagdollTorsoLeftAttachment"
	torsoLeftAttachment.Position = Vector3.new(-0.5, -1, 0)
	torsoLeftAttachment.Parent = model:FindFirstChild("Torso")

	local torsoRightAttachment = Instance.new("Attachment")
	torsoRightAttachment.Name = "RagdollTorsoRightAttachment"
	torsoRightAttachment.Position = Vector3.new(0.5, -1, 0)
	torsoRightAttachment.Parent = model:FindFirstChild("Torso")

	local headAttachment = Instance.new("Attachment")
	headAttachment.Name = "RagdollHeadAttachment"
	headAttachment.Position = Vector3.new(0, -0.5, 0)
	headAttachment.Parent = model:FindFirstChild("Head")

	local leftArmAttachment = Instance.new("Attachment")
	leftArmAttachment.Name = "RagdollLeftArmAttachment"
	leftArmAttachment.Position = Vector3.new(0.5, 1, 0)
	leftArmAttachment.Parent = model:FindFirstChild("Left Arm")

	local ragdollRightArmAttachment = Instance.new("Attachment")
	ragdollRightArmAttachment.Name = "RagdollRightArmAttachment"
	ragdollRightArmAttachment.Position = Vector3.new(-0.5, 1, 0)
	ragdollRightArmAttachment.Parent = model:FindFirstChild("Right Arm")

	local query = find(model)

	return {
		Head = query(
			{"Torso", "NeckAttachment"},
			{"Head", "RagdollHeadAttachment"},
			R6_HEAD_LIMITS),
		["Left Arm"] = query(
			{"Torso", "LeftCollarAttachment"},
			{"Left Arm", "RagdollLeftArmAttachment"},
			R6_SHOULDER_LIMITS),
		["Right Arm"] = query(
			{"Torso", "RightCollarAttachment"},
			{"Right Arm", "RagdollRightArmAttachment"},
			R6_SHOULDER_LIMITS),
		["Left Leg"] = createJointData(torsoLeftAttachment, leftLegAttachment, R6_HIP_LIMITS),
		["Right Leg"] = createJointData(torsoRightAttachment, rightLegAttachment, R6_HIP_LIMITS),
	}
end

function RagdollRigtypes.getR15Attachments(model)
	local query = find(model)

	return {
		Head = query(
			{"UpperTorso", "NeckRigAttachment"},
			{"Head", "NeckRigAttachment"},
			HEAD_LIMITS),

		LowerTorso = query(
			{"UpperTorso", "WaistRigAttachment"},
			{"LowerTorso", "RootRigAttachment"},
			LOWER_TORSO_LIMITS),

		LeftUpperArm = query(
			{"UpperTorso", "LeftShoulderRigAttachment"},
			{"LeftUpperArm", "LeftShoulderRigAttachment"},
			SHOULDER_LIMITS),
		LeftLowerArm = query(
			{"LeftUpperArm", "LeftElbowRigAttachment"},
			{"LeftLowerArm", "LeftElbowRigAttachment"},
			ELBOW_LIMITS),
		LeftHand = query(
			{"LeftLowerArm", "LeftWristRigAttachment"},
			{"LeftHand", "LeftWristRigAttachment"},
			HAND_FOOT_LIMITS),

		RightUpperArm = query(
			{"UpperTorso", "RightShoulderRigAttachment"},
			{"RightUpperArm", "RightShoulderRigAttachment"},
			SHOULDER_LIMITS),
		RightLowerArm = query(
			{"RightUpperArm", "RightElbowRigAttachment"},
			{"RightLowerArm", "RightElbowRigAttachment"},
			ELBOW_LIMITS),
		RightHand = query(
			{"RightLowerArm", "RightWristRigAttachment"},
			{"RightHand", "RightWristRigAttachment"},
			HAND_FOOT_LIMITS),

		LeftUpperLeg = query(
			{"LowerTorso", "LeftHipRigAttachment"},
			{"LeftUpperLeg", "LeftHipRigAttachment"},
			HIP_LIMITS),
		LeftLowerLeg = query(
			{"LeftUpperLeg", "LeftKneeRigAttachment"},
			{"LeftLowerLeg", "LeftKneeRigAttachment"},
			KNEE_LIMITS),
		LeftFoot = query(
			{"LeftLowerLeg", "LeftAnkleRigAttachment"},
			{"LeftFoot", "LeftAnkleRigAttachment"},
			HAND_FOOT_LIMITS),

		RightUpperLeg = query(
			{"LowerTorso", "RightHipRigAttachment"},
			{"RightUpperLeg", "RightHipRigAttachment"},
			HIP_LIMITS),
		RightLowerLeg = query(
			{"RightUpperLeg", "RightKneeRigAttachment"},
			{"RightLowerLeg", "RightKneeRigAttachment"},
			KNEE_LIMITS),
		RightFoot = query(
			{"RightLowerLeg", "RightAnkleRigAttachment"},
			{"RightFoot", "RightAnkleRigAttachment"},
			HAND_FOOT_LIMITS),
	}
end

function RagdollRigtypes.getR6NoCollisions(model)
	local list = {}

	local function addPair(pair)
		local part0 = model:FindFirstChild(pair[1])
		local part1 = model:FindFirstChild(pair[2])

		if part0 and part1 then
			table.insert(list, {part0, part1})
		end
	end

	addPair({"Head", "Torso"})
	addPair({"Left Arm", "Torso"})
	addPair({"Right Arm", "Torso"})
	addPair({"Left Leg", "Torso"})
	addPair({"Right Leg", "Torso"})

	addPair({"Left Leg", "Right Leg"})

	return list
end


function RagdollRigtypes.getR15NoCollisions(model)
	local list = {}

	local function addPair(pair)
		local part0 = model:FindFirstChild(pair[1])
		local part1 = model:FindFirstChild(pair[2])

		if part0 and part1 then
			table.insert(list, {part0, part1})
		end
	end

	addPair({"Head", "UpperTorso"})
	addPair({"UpperTorso", "LowerTorso"})

	addPair({"UpperTorso", "LeftUpperArm"})
	addPair({"LowerTorso", "LeftUpperArm"})
	addPair({"LeftUpperArm", "LeftLowerArm"})
	addPair({"LeftLowerArm", "LeftHand"})

	addPair({"UpperTorso", "RightUpperArm"})
	addPair({"LowerTorso", "RightUpperArm"})
	addPair({"RightUpperArm", "RightLowerArm"})
	addPair({"RightLowerArm", "RightHand"})

	addPair({"LeftUpperLeg", "RightUpperLeg"})

	addPair({"UpperTorso", "RightUpperLeg"})
	addPair({"LowerTorso", "RightUpperLeg"})
	addPair({"RightUpperLeg", "RightLowerLeg"})
	addPair({"RightLowerLeg", "RightFoot"})

	addPair({"UpperTorso", "LeftUpperLeg"})
	addPair({"LowerTorso", "LeftUpperLeg"})
	addPair({"LeftUpperLeg", "LeftLowerLeg"})
	addPair({"LeftLowerLeg", "LeftFoot"})

	return list
end

return RagdollRigtypes