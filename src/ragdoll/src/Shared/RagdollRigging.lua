--[=[
	Rigging data for humaoid ragdolls.
	@class RagdollRigging
]=]

local RunService = game:GetService("RunService")

local RagdollRigging = {}

-- Gravity that joint friction values were tuned under.
local REFERENCE_GRAVITY = 196.2

-- ReferenceMass values from mass of child part. Used to normalized "stiffness" for differently
-- sized avatars (with different mass).
local DEFAULT_MAX_FRICTION_TORQUE = 0.5 --500

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
	ReferenceMass = 0.43671694397926,
}

local ELBOW_LIMITS = {
	-- Elbow is basically a hinge, but allow some twist for Supination and Pronation
	UpperAngle = 20,
	TwistLowerAngle = 5,
	TwistUpperAngle = 120,
	ReferenceMass = 0.70196455717087,
}

local WRIST_LIMITS = {
	UpperAngle = 30,
	TwistLowerAngle = -10,
	TwistUpperAngle = 10,
	ReferenceMass = 0.69132566452026,
}

local KNEE_LIMITS = {
	UpperAngle = 5,
	TwistLowerAngle = -120,
	TwistUpperAngle = -5,
	ReferenceMass = 0.65389388799667,
}

local SHOULDER_LIMITS = {
	UpperAngle = 110,
	TwistLowerAngle = -85,
	TwistUpperAngle = 85,
	FrictionTorque = 0,
	ReferenceMass = 0.90918225049973,
}

local HIP_LIMITS = {
	UpperAngle = 40,
	TwistLowerAngle = -5,
	TwistUpperAngle = 80,
	FrictionTorque = 0,
	ReferenceMass = 1.9175016880035,
}

local R6_HEAD_LIMITS = {
	UpperAngle = 30,
	TwistLowerAngle = -40,
	TwistUpperAngle = 40,
}

local R6_SHOULDER_LIMITS = {
	UpperAngle = 110,
	TwistLowerAngle = -85,
	TwistUpperAngle = 85,
}

local R6_HIP_LIMITS = {
	UpperAngle = 40,
	TwistLowerAngle = -5,
	TwistUpperAngle = 80,
}

local V3_ZERO = Vector3.new()
local V3_UP = Vector3.new(0, 1, 0)
local V3_DOWN = Vector3.new(0, -1, 0)
local V3_RIGHT = Vector3.new(1, 0, 0)
local V3_LEFT = Vector3.new(-1, 0, 0)

-- To model shoulder cone and twist limits correctly we really need the primary axis of the UpperArm
-- to be going down the limb. the waist and neck joints attachments actually have the same problem
-- of non-ideal axis orientation, but it's not as noticable there since the limits for natural
-- motion are tighter for those joints anyway.

-- luacheck: push ignore
local R15_ADDITIONAL_ATTACHMENTS = {
	{"UpperTorso", "RightShoulderRagdollAttachment", CFrame.fromMatrix(V3_ZERO, V3_RIGHT, V3_UP), "RightShoulderRigAttachment"},
	{"RightUpperArm", "RightShoulderRagdollAttachment", CFrame.fromMatrix(V3_ZERO, V3_DOWN, V3_RIGHT), "RightShoulderRigAttachment"},
	{"UpperTorso", "LeftShoulderRagdollAttachment", CFrame.fromMatrix(V3_ZERO, V3_LEFT, V3_UP), "LeftShoulderRigAttachment"},
	{"LeftUpperArm", "LeftShoulderRagdollAttachment", CFrame.fromMatrix(V3_ZERO, V3_DOWN, V3_LEFT), "LeftShoulderRigAttachment"},
}
-- luacheck: pop

-- { { Part0 name (parent), Part1 name (child, parent of joint), attachmentName, limits }, ... }
local R15_RAGDOLL_RIG = {
	{"UpperTorso", "Head", "NeckRigAttachment", HEAD_LIMITS},

	{"LowerTorso", "UpperTorso", "WaistRigAttachment", WAIST_LIMITS},

	{"UpperTorso", "LeftUpperArm", "LeftShoulderRagdollAttachment", SHOULDER_LIMITS},
	{"LeftUpperArm", "LeftLowerArm", "LeftElbowRigAttachment", ELBOW_LIMITS},
	{"LeftLowerArm", "LeftHand", "LeftWristRigAttachment", WRIST_LIMITS},

	{"UpperTorso", "RightUpperArm", "RightShoulderRagdollAttachment", SHOULDER_LIMITS},
	{"RightUpperArm", "RightLowerArm", "RightElbowRigAttachment", ELBOW_LIMITS},
	{"RightLowerArm", "RightHand", "RightWristRigAttachment", WRIST_LIMITS},

	{"LowerTorso", "LeftUpperLeg", "LeftHipRigAttachment", HIP_LIMITS},
	{"LeftUpperLeg", "LeftLowerLeg", "LeftKneeRigAttachment", KNEE_LIMITS},
	{"LeftLowerLeg", "LeftFoot", "LeftAnkleRigAttachment", ANKLE_LIMITS},

	{"LowerTorso", "RightUpperLeg", "RightHipRigAttachment", HIP_LIMITS},
	{"RightUpperLeg", "RightLowerLeg", "RightKneeRigAttachment", KNEE_LIMITS},
	{"RightLowerLeg", "RightFoot", "RightAnkleRigAttachment", ANKLE_LIMITS},
}
-- { { Part0 name, Part1 name }, ... }
local R15_NO_COLLIDES = {
	{"LowerTorso", "LeftUpperArm"},
	{"LeftUpperArm", "LeftHand"},

	{"LowerTorso", "RightUpperArm"},
	{"RightUpperArm", "RightHand"},

	{"LeftUpperLeg", "RightUpperLeg"},

	{"UpperTorso", "RightUpperLeg"},
	{"RightUpperLeg", "RightFoot"},

	{"UpperTorso", "LeftUpperLeg"},
	{"LeftUpperLeg", "LeftFoot"},

	-- Support weird R15 rigs
	{"UpperTorso", "LeftLowerLeg"},
	{"UpperTorso", "RightLowerLeg"},
	{"LowerTorso", "LeftLowerLeg"},
	{"LowerTorso", "RightLowerLeg"},

	{"UpperTorso", "LeftLowerArm"},
	{"UpperTorso", "RightLowerArm"},

	{"Head", "LeftUpperArm"},
	{"Head", "RightUpperArm"},
}
-- { { Motor6D name, Part name }, ...}, must be in tree order, important for ApplyJointVelocities
local R15_MOTOR6DS = {
	{"Waist", "UpperTorso"},

	{"Neck", "Head"},

	{"LeftShoulder", "LeftUpperArm"},
	{"LeftElbow", "LeftLowerArm"},
	{"LeftWrist", "LeftHand"},

	{"RightShoulder", "RightUpperArm"},
	{"RightElbow", "RightLowerArm"},
	{"RightWrist", "RightHand"},

	{"LeftHip", "LeftUpperLeg"},
	{"LeftKnee", "LeftLowerLeg"},
	{"LeftAnkle", "LeftFoot"},

	{"RightHip", "RightUpperLeg"},
	{"RightKnee", "RightLowerLeg"},
	{"RightAnkle", "RightFoot"},
}

-- R6 has hard coded part sizes and does not have a full set of rig Attachments.
local R6_ADDITIONAL_ATTACHMENTS = {
	{"Head", "NeckAttachment", CFrame.new(0, -0.5, 0)},

	{"Torso", "RightShoulderRagdollAttachment", CFrame.fromMatrix(Vector3.new(1, 0.5, 0), V3_RIGHT, V3_UP)},
	{"Right Arm", "RightShoulderRagdollAttachment", CFrame.fromMatrix(Vector3.new(-0.5, 0.5, 0), V3_DOWN, V3_RIGHT)},

	{"Torso", "LeftShoulderRagdollAttachment", CFrame.fromMatrix(Vector3.new(-1, 0.5, 0), V3_LEFT, V3_UP)},
	{"Left Arm", "LeftShoulderRagdollAttachment", CFrame.fromMatrix(Vector3.new(0.5, 0.5, 0), V3_DOWN, V3_LEFT)},

	{"Torso", "RightHipAttachment", CFrame.new(0.5, -1, 0)},
	{"Right Leg", "RightHipAttachment", CFrame.new(0, 1, 0)},

	{"Torso", "LeftHipAttachment", CFrame.new(-0.5, -1, 0)},
	{"Left Leg", "LeftHipAttachment", CFrame.new(0, 1, 0)},
}
-- R6 rig tables use the same table structures as R15.
local R6_RAGDOLL_RIG = {
	{"Torso", "Head", "NeckAttachment", R6_HEAD_LIMITS},

	{"Torso", "Left Leg", "LeftHipAttachment", R6_HIP_LIMITS},
	{"Torso", "Right Leg", "RightHipAttachment", R6_HIP_LIMITS},

	{"Torso", "Left Arm", "LeftShoulderRagdollAttachment", R6_SHOULDER_LIMITS},
	{"Torso", "Right Arm", "RightShoulderRagdollAttachment", R6_SHOULDER_LIMITS},
}
local R6_NO_COLLIDES = {
	{"Left Leg", "Right Leg"},
	{"Head", "Right Arm"},
	{"Head", "Left Arm"},
}
local R6_MOTOR6DS = {
	{"Neck", "Torso"},
	{"Left Shoulder", "Torso"},
	{"Right Shoulder", "Torso"},
	{"Left Hip", "Torso"},
	{"Right Hip", "Torso"},
}

local BALL_SOCKET_NAME = "RagdollBallSocket"
local NO_COLLIDE_NAME = "RagdollNoCollision"

-- Index parts by name to save us from many O(n) FindFirstChild searches
local function indexParts(model)
	local parts = {}
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			local name = child.name
			-- Index first, mimicing FindFirstChild
			if not parts[name] then
				parts[name] = child
			end
		end
	end
	return parts
end

local function createRigJoints(parts, rig)
	for _, params in ipairs(rig) do
		local part0Name, part1Name, attachmentName, limits = unpack(params)
		local part0 = parts[part0Name]
		local part1 = parts[part1Name]
		if part0 and part1 then
			local a0 = part0:FindFirstChild(attachmentName)
			local a1 = part1:FindFirstChild(attachmentName)
			if a0 and a1 and a0:IsA("Attachment") and a1:IsA("Attachment") then
				-- Our rigs only have one joint per part (connecting each part to it's parent part), so
				-- we can re-use it if we have to re-rig that part again.
				local constraint = part1:FindFirstChild(BALL_SOCKET_NAME)
				if not constraint then
					constraint = Instance.new("BallSocketConstraint")
					constraint.Name = BALL_SOCKET_NAME

					if RunService:IsClient() then
						warn(("[RagdollRigging] - Creating BallSocketConstraint %q"))
					end
				end
				constraint.Attachment0 = a0
				constraint.Attachment1 = a1
				constraint.LimitsEnabled = true
				constraint.UpperAngle = limits.UpperAngle
				constraint.TwistLimitsEnabled = true
				constraint.TwistLowerAngle = limits.TwistLowerAngle
				constraint.TwistUpperAngle = limits.TwistUpperAngle
				-- Scale constant torque limit for joint friction relative to gravity and the mass of
				-- the body part.
				local gravityScale = workspace.Gravity / REFERENCE_GRAVITY
				local referenceMass = limits.ReferenceMass
				local massScale = referenceMass and (part1:GetMass() / referenceMass) or 1
				local maxTorque = limits.FrictionTorque or DEFAULT_MAX_FRICTION_TORQUE
				constraint.MaxFrictionTorque = maxTorque * massScale * gravityScale
				constraint.Parent = part1
			end
		end
	end
end

local function createAdditionalAttachments(parts, attachments)
	for _, attachmentParams in ipairs(attachments) do
		local partName, attachmentName, cframe, baseAttachmentName = unpack(attachmentParams)
		local part = parts[partName]
		if part then
			local attachment = part:FindFirstChild(attachmentName)
			-- Create or update existing attachment
			if not attachment or attachment:IsA("Attachment") then
				if baseAttachmentName then
					local base = part:FindFirstChild(baseAttachmentName)
					if base and base:IsA("Attachment") then
						cframe = base.CFrame * cframe
					end
				end
				-- The attachment names are unique within a part, so we can re-use
				if not attachment then
					attachment = Instance.new("Attachment")
					attachment.Name = attachmentName
					attachment.CFrame = cframe
					attachment.Parent = part

					if RunService:IsClient() then
						warn(("[RagdollRigging] - Creating attachment %q"):format(attachmentName))
					end
				else
					attachment.CFrame = cframe
				end
			end
		end
	end
end

local function createNoCollides(parts, noCollides)
	-- This one's trickier to handle for an already rigged character since a part will have multiple
	-- NoCollide children with the same name. Having fewer unique names is better for
	-- replication so we suck it up and deal with the complexity here.

	-- { [Part1] = { [Part0] = true, ... }, ...}
	local needed = {}
	-- Following the convention of the Motor6Ds and everything else here we parent the NoCollide to
	-- Part1, so we start by building the set of Part0s we need a NoCollide with for each Part1
	for _, namePair in ipairs(noCollides) do
		local part0Name, part1Name = unpack(namePair)
		local p0, p1 = parts[part0Name], parts[part1Name]
		if p0 and p1 then
			local p0Set = needed[p1]
			if not p0Set then
				p0Set = {}
				needed[p1] = p0Set
			end
			p0Set[p0] = true
		end
	end

	-- Go through NoCollides that exist and remove Part0s from the needed set if we already have
	-- them covered. Gather NoCollides that aren't between parts in the set for resue
	local reusableNoCollides = {}
	for part1, neededPart0s in pairs(needed) do
		local reusables = {}
		for _, child in ipairs(part1:GetChildren()) do
			if child:IsA("NoCollisionConstraint") and child.Name == NO_COLLIDE_NAME then
				local p0 = child.Part0
				local p1 = child.Part1
				if p1 == part1 and neededPart0s[p0] then
					-- If this matches one that we needed, we don't need to create it anymore.
					neededPart0s[p0] = nil
				else
					-- Otherwise we're free to reuse this NoCollide
					table.insert(reusables, child)
				end
			end
		end
		reusableNoCollides[part1] = reusables
	end

	-- Create the remaining NoCollides needed, re-using old ones if possible
	for part1, neededPart0s in pairs(needed) do
		local reusables = reusableNoCollides[part1]
		for part0, _ in pairs(neededPart0s) do
			local constraint = table.remove(reusables)
			if not constraint then
				constraint = Instance.new("NoCollisionConstraint")
				if RunService:IsClient() then
					warn(("[RagdollRigging] - Creating NoCollisionConstraint %q"))
				end
			end
			constraint.Name = NO_COLLIDE_NAME
			constraint.Part0 = part0
			constraint.Part1 = part1
			constraint.Parent = part1
		end
	end
end

local function getMotorSet(model, motorSet)
	local motors = {}

	-- Disable all regular joints:
	for _, params in pairs(motorSet) do
		local part = model:FindFirstChild(params[2])
		if part then
			local motor = part:FindFirstChild(params[1])
			if motor and motor:IsA("Motor6D") then
				table.insert(motors, motor)
			end
		end
	end

	return motors
end

--[=[
	Creates joints on a model for a given rig type.
	@param model Model
	@param rigType HumanoidRigType
]=]
function RagdollRigging.createRagdollJoints(model, rigType)
	local parts = indexParts(model)
	if rigType == Enum.HumanoidRigType.R6 then
		createAdditionalAttachments(parts, R6_ADDITIONAL_ATTACHMENTS)
		createRigJoints(parts, R6_RAGDOLL_RIG)
		createNoCollides(parts, R6_NO_COLLIDES)
	elseif rigType == Enum.HumanoidRigType.R15 then
		createAdditionalAttachments(parts, R15_ADDITIONAL_ATTACHMENTS)
		createRigJoints(parts, R15_RAGDOLL_RIG)
		createNoCollides(parts, R15_NO_COLLIDES)
	else
		error("unknown rig type", 2)
	end
end

--[=[
	Removes ragdoll joints for a given model
	@param model Model
]=]
function RagdollRigging.removeRagdollJoints(model)
	for _, descendant in pairs(model:GetDescendants()) do
		-- Remove BallSockets and NoCollides, leave the additional Attachments
		if (descendant:IsA("BallSocketConstraint") and descendant.Name == BALL_SOCKET_NAME)
			or (descendant:IsA("NoCollisionConstraint") and descendant.Name == NO_COLLIDE_NAME)
		then
			descendant:Destroy()
		end
	end
end

--[=[
	Retrieves all joint motors for a given rigType
	@param model Model
	@param rigType HumanoidRigType
]=]
function RagdollRigging.getMotors(model, rigType)
	-- Note: We intentionally do not disable the root joint so that the mechanism root of the
	-- character stays consistent when we break joints on the client. This avoid the need for the client to wait
	-- for re-assignment of network ownership of a new mechanism, which creates a visible hitch.

	local motors
	if rigType == Enum.HumanoidRigType.R6 then
		motors = getMotorSet(model, R6_MOTOR6DS)
	elseif rigType == Enum.HumanoidRigType.R15 then
		motors = getMotorSet(model, R15_MOTOR6DS)
	else
		error("unknown rig type", 2)
	end

	return motors
end

--[=[
	Disables all particle emitters and fades them out. Yields for the duration.

	@yields
	@param character Model
	@param duration number
]=]
function RagdollRigging.disableParticleEmittersAndFadeOutYielding(character, duration)
	if RunService:IsServer() then
		-- This causes a lot of unnecesarry replicated property changes
		error("disableParticleEmittersAndFadeOutYielding should not be called on the server.", 2)
	end

	local descendants = character:GetDescendants()
	local transparencies = {}
	for _, instance in pairs(descendants) do
		if instance:IsA("BasePart") or instance:IsA("Decal") then
			transparencies[instance] = instance.Transparency
		elseif instance:IsA("ParticleEmitter") then
			instance.Enabled = false
		end
	end
	local t = 0
	while t < duration do
		-- Using heartbeat because we want to update just before rendering next frame, and not
		-- block the render thread kicking off (as RenderStepped does)
		local dt = RunService.Heartbeat:Wait()
		t = t + dt
		local alpha = math.min(t / duration, 1)
		for part, initialTransparency in pairs(transparencies) do
			part.Transparency = (1 - alpha) * initialTransparency + alpha
		end
	end
end

--[=[
	Applies a sliding friction torque to the character making it stiffer and stiffer. Yields.

	@yields
	@param character Model
	@param duration number
]=]
function RagdollRigging.easeJointFriction(character, duration)
	local descendants = character:GetDescendants()
	-- { { joint, initial friction, end friction }, ... }
	local frictionJoints = {}
	for _, v in pairs(descendants) do
		if v:IsA("BallSocketConstraint") and v.Name == BALL_SOCKET_NAME then
			local current = v.MaxFrictionTorque
			-- Keep the torso and neck a little stiffer...
			local parentName = v.Parent.Name
			local scale = (parentName == "UpperTorso" or parentName == "Head") and 0.5 or 0.05
			local next = current * scale
			frictionJoints[v] = { v, current, next }
		end
	end
	local t = 0
	while t < duration do
		-- Using stepped because we want to update just before physics sim
		local _, dt = RunService.Stepped:Wait()
		t = t + dt
		local alpha = math.min(t / duration, 1)
		for _, tuple in pairs(frictionJoints) do
			local ballSocket, a, b = unpack(tuple)
			ballSocket.MaxFrictionTorque = (1 - alpha) * a + alpha * b
		end
	end
end

return RagdollRigging