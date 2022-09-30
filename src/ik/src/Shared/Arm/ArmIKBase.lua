--[=[
	Provides IK for a given arm
	@class ArmIKBase
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local IKAimPositionPriorites = require("IKAimPositionPriorites")
local IKResource = require("IKResource")
local IKResourceUtils = require("IKResourceUtils")
local LimbIKUtils = require("LimbIKUtils")
local Maid = require("Maid")
local Math = require("Math")
local QFrame = require("QFrame")
local RagdollConstants = require("RagdollConstants")

local CFA_90X = CFrame.Angles(math.pi/2, 0, 0)
local USE_OLD_IK_SYSTEM = false

local ArmIKBase = setmetatable({}, BaseObject)
ArmIKBase.ClassName = "ArmIKBase"
ArmIKBase.__index = ArmIKBase

function ArmIKBase.new(humanoid, armName)
	local self = setmetatable(BaseObject.new(), ArmIKBase)

	self._humanoid = humanoid or error("No humanoid")

	self._grips = {}

	if armName == "Left" then
		self._direction = 1
	elseif armName == "Right" then
		self._direction = -1
	else
		error("Bad arm")
	end

	self._resources = IKResource.new(IKResourceUtils.createResource({
		name = "Character";
		robloxName = self._humanoid.Parent.Name;
		children = {
			IKResourceUtils.createResource({
				name = "UpperTorso";
				robloxName = "UpperTorso";
				children = {
					IKResourceUtils.createResource({
						name = "UpperTorsoShoulderRigAttachment";
						robloxName = armName .. "ShoulderRigAttachment";
					});
				};
			});
			IKResourceUtils.createResource({
				name = "UpperArm";
				robloxName = armName .. "UpperArm";
				children = {
					IKResourceUtils.createResource({
						name = "Shoulder";
						robloxName = armName .. "Shoulder";
					});
					IKResourceUtils.createResource({
						name = "UpperArmShoulderRigAttachment";
						robloxName = armName .. "ShoulderRigAttachment";
					});
					IKResourceUtils.createResource({
						name = "UpperArmElbowRigAttachment";
						robloxName = armName .. "ElbowRigAttachment";
					});
				};
			});
			IKResourceUtils.createResource({
				name = "LowerArm";
				robloxName = armName .. "LowerArm";
				children = {
					IKResourceUtils.createResource({
						name = "Elbow";
						robloxName = armName .. "Elbow";
					});
					IKResourceUtils.createResource({
						name = "LowerArmElbowRigAttachment";
						robloxName = armName .. "ElbowRigAttachment";
					});
					IKResourceUtils.createResource({
						name = "LowerArmWristRigAttachment";
						robloxName = armName .. "WristRigAttachment";
					});
				};
			});
			IKResourceUtils.createResource({
				name = "Hand";
				robloxName = armName .. "Hand";
				children = {
					IKResourceUtils.createResource({
						name = "Wrist";
						robloxName = armName .. "Wrist";
					});
					IKResourceUtils.createResource({
						name = "HandWristRigAttachment";
						robloxName = armName .. "WristRigAttachment";
					});
					IKResourceUtils.createResource({
						name = "HandGripAttachment";
						robloxName = armName .. "GripAttachment";
					});
				};
			});
		}
	}))

	self._maid:GiveTask(self._resources)
	self._resources:SetInstance(self._humanoid.Parent or error("No humanoid.Parent"))

	self._gripping = Instance.new("BoolValue")
	self._gripping.Value = false
	self._maid:GiveTask(self._gripping)

	self._maid:GiveTask(self._gripping.Changed:Connect(function()
		self:_updateMotorsEnabled()
	end))
	self:_updateMotorsEnabled()

	return self
end

function ArmIKBase:Grip(attachment, priority)
	local gripData = {
		attachment = attachment;
		priority = priority or IKAimPositionPriorites.DEFAULT;
	}

	local i = 1
	while self._grips[i] and self._grips[i].priority > priority do
		i = i + 1
	end

	table.insert(self._grips, i, gripData)
	self._gripping.Value = true

	return function()
		if self.Destroy then
			self:_stopGrip(gripData)
		end
	end
end

function ArmIKBase:_stopGrip(grip)
	for index, value in pairs(self._grips) do
		if value == grip then
			table.remove(self._grips, index)
			break
		end
	end

	if not next(self._grips) then
		self._gripping.Value = false
	end
end

-- Sets transform
function ArmIKBase:UpdateTransformOnly()
	if not self._grips[1] then
		return
	end
	if not (self._shoulderTransform and self._elbowTransform and self._wristTransform) then
		return
	end
	if not self._resources:IsReady() then
		return
	end

	local shoulder = self._resources:Get("Shoulder")
	local elbow = self._resources:Get("Elbow")
	local wrist = self._resources:Get("Wrist")

	if RunService:IsRunning() then
		shoulder.Transform = self._shoulderTransform
		elbow.Transform = self._elbowTransform
		wrist.Transform = self._wristTransform
	else
		-- Test mode/story mode
		if not self._initTest then
			self._initTest = true
			self._testDefaultShoulderC0 = shoulder.C0
			self._testDefaultElbowC0 = elbow.C0
			self._testDefaultWristC0 = wrist.C0
		end

		shoulder.C0 = self._testDefaultShoulderC0 * self._shoulderTransform
		elbow.C0 = self._testDefaultElbowC0 * self._elbowTransform
		wrist.C0 = self._testDefaultWristC0 * self._wristTransform
	end
end

function ArmIKBase:Update()
	if USE_OLD_IK_SYSTEM then
		if self:_oldUpdatePoint() then
			local shoulderXAngle = self._shoulderXAngle
			local elbowXAngle = self._elbowXAngle

			local yrot = CFrame.new(Vector3.new(), self._offset)

			self._shoulderTransform = (yrot * CFA_90X * CFrame.Angles(shoulderXAngle, 0, 0)) --:inverse()
			self._elbowTransform = CFrame.Angles(elbowXAngle, 0, 0)
			self._wristTransform = CFrame.new()

			self:UpdateTransformOnly()
		end
	else
		if self:_newUpdate() then
			self:UpdateTransformOnly()
		end
	end
end

function ArmIKBase:_oldUpdatePoint()
	local grip = self._grips[1]
	if not grip then
		self:_clear()
		return false
	end

	if not self:_oldCalculatePoint(grip.attachment.WorldPosition) then
		self:_clear()
		return false
	end

	return true
end

function ArmIKBase:_clear()
	self._offset = nil
	self._elbowTransform = nil
	self._shoulderTransform = nil
	self._wristTransform = nil
end

function ArmIKBase:_newUpdate()
	local grip = self._grips[1]
	if not (grip and self._resources:IsReady()) then
		self._elbowTransform = nil
		self._shoulderTransform = nil
		self._wristTransform = nil
		return false
	end

	local targetCFrame = grip.attachment.WorldCFrame

	local upperTorsoShoulderRigAttachment = self._resources:Get("UpperTorsoShoulderRigAttachment")

	local upperArmShoulderRigAttachment = self._resources:Get("UpperArmShoulderRigAttachment")
	local upperArmElbowRigAttachment = self._resources:Get("UpperArmElbowRigAttachment")
	local elbowOffset = upperArmElbowRigAttachment.Position - upperArmShoulderRigAttachment.Position

	local lowerArmElbowRigAttachment = self._resources:Get("LowerArmElbowRigAttachment")
	local lowerArmWristRigAttachment = self._resources:Get("LowerArmWristRigAttachment")
	local wristOffset = lowerArmWristRigAttachment.Position - lowerArmElbowRigAttachment.Position

	local handWristRigAttachment = self._resources:Get("HandWristRigAttachment")
	local handGripAttachment = self._resources:Get("HandGripAttachment")
	local handOffset = handGripAttachment.Position - handWristRigAttachment.Position

	-- TODO: Cache config
	local config = LimbIKUtils.createConfig(elbowOffset, wristOffset + handOffset, 1)
	local relTargetCFrame = upperTorsoShoulderRigAttachment.WorldCFrame:toObjectSpace(targetCFrame)

	-- TODO: Allow configuration
	local ELBOW_ANGLE = math.rad(20)
	local shoulderQFrame, elbowQFrame, wristQFrame = LimbIKUtils.solveLimb(config, QFrame.fromCFrameClosestTo(relTargetCFrame, QFrame.new()), self._direction*ELBOW_ANGLE)

	self._shoulderTransform = QFrame.toCFrame(shoulderQFrame)
	self._elbowTransform = QFrame.toCFrame(elbowQFrame)
	self._wristTransform = QFrame.toCFrame(wristQFrame)

	return true
end

function ArmIKBase:_oldCalculatePoint(targetPositionWorld)
	if not self._resources:IsReady() then
		return false
	end

	local shoulder = self._resources:Get("Shoulder")
	local elbow = self._resources:Get("Elbow")
	local wrist = self._resources:Get("Wrist")
	local gripAttachment = self._resources:Get("HandGripAttachment")
	if not (shoulder.Part0 and elbow.Part0 and elbow.Part1) then
		return false
	end

	local base = shoulder.Part0.CFrame * (self._testDefaultShoulderC0 or shoulder.C0)
	local elbowCFrame = elbow.Part0.CFrame * (self._testDefaultElbowC0 or elbow.C0)
	local wristCFrame = elbow.Part1.CFrame * (self._testDefaultWristC0 or wrist.C0)

	local r0 = (base.Position - elbowCFrame.Position).Magnitude
	local r1 = (elbowCFrame.Position - wristCFrame.Position).Magnitude

	r1 = r1 + (gripAttachment.WorldPosition - wristCFrame.Position).Magnitude

	local offset = base:pointToObjectSpace(targetPositionWorld)
	local d = offset.Magnitude

	if d > (r0 + r1) then -- Case: Circles are seperate
		d = r0 + r1
	end

	if d == 0 then
		return false
	end

	local baseAngle = Math.lawOfCosines(r0, d, r1)
	local elbowAngle = Math.lawOfCosines(r1, r0, d) -- Solve for angle across from d

	if not (baseAngle and elbowAngle) then
		return false
	end

	elbowAngle = (elbowAngle - math.pi)
	if elbowAngle > -math.pi/32 then -- Force a bit of bent elbow
		elbowAngle = -math.pi/32
	end

	self._shoulderXAngle = -baseAngle
	self._elbowXAngle = -elbowAngle
	self._offset = offset.unit * d

	return true
end

function ArmIKBase:_updateMotorsEnabled()
	self._maid._gripMaid = nil

	if not self._gripping.Value then
		return
	end

	local gripMaid = Maid.new()

	gripMaid:GiveTask(self._resources.ReadyChanged:Connect(function()
		gripMaid._attributes = self:_setAttributes()
	end))
	gripMaid._attributes = self:_setAttributes()

	self._maid._gripMaid = gripMaid
end

function ArmIKBase:_setAttributes()
	if not self._resources:IsReady() then
		return nil
	end

	local maid = Maid.new()

	local shoulder = self._resources:Get("Shoulder")
	local elbow = self._resources:Get("Elbow")
	local wrist = self._resources:Get("Wrist")

	shoulder:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, true)
	elbow:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, true)
	wrist:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, true)

	maid:GiveTask(function()
		shoulder:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, false)
		elbow:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, false)
		wrist:SetAttribute(RagdollConstants.IS_MOTOR_ANIMATED_ATTRIBUTE, false)
	end)

	return maid
end

return ArmIKBase