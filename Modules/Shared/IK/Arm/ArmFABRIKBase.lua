--- Provides IK for a given arm
-- @classmod ArmFABRIKBase

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local IKResource = require("IKResource")
local IKResourceUtils = require("IKResourceUtils")
local FABRIKUtils = require("FABRIKUtils")
local FABRIKChain = require("FABRIKChain")
local FABRIKConstraint = require("FABRIKConstraint")
local IKAimPositionPriorites = require("IKAimPositionPriorites")

local CFA_90X = CFrame.Angles(math.pi/2, 0, 0)

local ArmFABRIKBase = setmetatable({}, BaseObject)
ArmFABRIKBase.ClassName = "ArmFABRIKBase"
ArmFABRIKBase.__index = ArmFABRIKBase

function ArmFABRIKBase.new(humanoid, armName)
	local self = setmetatable(BaseObject.new(), ArmFABRIKBase)

	self._humanoid = humanoid or error("No humanoid")
	assert(armName == "Left" or armName == "Right")

	self._grips = {}

	self._resources = IKResource.new(IKResourceUtils.createResource({
		name = "Character";
		robloxName = self._humanoid.Parent.Name;
		children = {
			IKResourceUtils.createResource({
				name = "RootPart";
				robloxName = "HumanoidRootPart";
			});
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
	self._resources:SetInstance(self._humanoid.Parent or error("No humanoid.Parent"))
	self._maid:GiveTask(self._resources)

	self._maid:GiveTask(self._resources.ReadyChanged:Connect(function()
		self:_rebuildChain()
	end))
	self:_rebuildChain()


	return self
end

function ArmFABRIKBase:Grip(attachment, priority)
	local gripData = {
		attachment = attachment;
		priority = priority or IKAimPositionPriorites.DEFAULT;
	}

	local i = 1
	while self._grips[i] and self._grips[i].priority < priority do
		i = i + 1
	end

	table.insert(self._grips, gripData)

	return function()
		if self.Destroy then
			self:_stopGrip(gripData)
		end
	end
end

function ArmFABRIKBase:_stopGrip(grip)
	for index, value in pairs(self._grips) do
		if value == grip then
			table.remove(self._grips, index)
			break
		end
	end
end

-- Sets transform
function ArmFABRIKBase:UpdateTransformOnly()
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

	shoulder.Transform = self._shoulderTransform
	elbow.Transform = self._elbowTransform
	wrist.Transform = self._wristTransform
end

function ArmFABRIKBase:Update()
	local grip = self:_getCurrentGrip()
	if not grip then
		self:_clear()
		return
	end

	if not self._resources:IsReady() then
		self:_clear()
		return
	end

	self:_calculateTransforms(grip.attachment.WorldPosition)

	self:UpdateTransformOnly()
end

function ArmFABRIKBase:_getCurrentGrip()
	return self._grips[1]
end

function ArmFABRIKBase:_clear()
	self._offset = nil
	self._elbowTransform = nil
	self._shoulderTransform = nil
end

function ArmFABRIKBase:_calculateTransforms(worldPosition)
	local upperShoulderRigAttachment = self._resources:Get("UpperTorsoShoulderRigAttachment")

	local baseCFrame = upperShoulderRigAttachment.WorldCFrame

	local relTarget = baseCFrame:pointToObjectSpace(worldPosition)

	self._chain:SetTarget(relTarget)
	self._chain:Solve()

	local bones = self._chain:GetBones()

	if game:GetService("RunService"):IsClient() then
		self._drawer = self._drawer or require("Drawer").new()
		self._drawer:Clear()
		for _, item in pairs(self._chain:GetPoints()) do
			self._maid[_ .. "pt"] = require("Draw").point(baseCFrame:pointToWorldSpace(item), nil, nil, 0.1)
		end

		-- self._drawer:CFrame(baseCFrame * bones[1]:GetAlignedCFrame(), workspace)
		-- self._drawer:CFrame(baseCFrame * bones[2]:GetAlignedCFrame(), workspace)
	end

	local function projectCFrame(attachment1, attachment2)
		return attachment1.CFrame:inverse() * attachment2.CFrame
	end

	local function getBoneCFrame(bone, worldCFrame)
		local alignedCFrameWorld = baseCFrame:toWorldSpace(bone:GetAlignedCFrame())
		local relative = worldCFrame:toObjectSpace(alignedCFrameWorld)

		-- self._drawer:CFrame(alignedCFrameWorld, workspace)

		return relative - relative.p
	end

	local shoulderCFrame = upperShoulderRigAttachment.WorldCFrame
	local shoulderTransform = getBoneCFrame(bones[1], shoulderCFrame) * CFA_90X
	local elbowCFrame = shoulderCFrame * shoulderTransform
			* projectCFrame(
				self._resources:Get("UpperArmShoulderRigAttachment"),
				self._resources:Get("UpperArmElbowRigAttachment"))

	local elbowTransform = getBoneCFrame(bones[2], elbowCFrame) * CFA_90X
	local wristCFrame = elbowCFrame * elbowTransform
			* projectCFrame(
				self._resources:Get("LowerArmElbowRigAttachment"),
				self._resources:Get("LowerArmWristRigAttachment"))

	local wristTransform = getBoneCFrame(bones[3], wristCFrame) * CFA_90X

	self._shoulderTransform = shoulderTransform
	self._elbowTransform = elbowTransform
	self._wristTransform = wristTransform
end

function ArmFABRIKBase:_rebuildChain()
	if not self._resources:IsReady() then
		return
	end

	-- snapshot our system as is
	local upperShoulderRigAttachment = self._resources:Get("UpperTorsoShoulderRigAttachment")
	local baseCFrame = upperShoulderRigAttachment.WorldCFrame

	local points = FABRIKUtils.pointsFromAttachment(baseCFrame, {
		{
			self._resources:Get("UpperArmShoulderRigAttachment");
			self._resources:Get("UpperArmElbowRigAttachment");
		};
		{
			self._resources:Get("LowerArmElbowRigAttachment");
			self._resources:Get("LowerArmWristRigAttachment");
		};
		{
			self._resources:Get("HandWristRigAttachment");
			self._resources:Get("HandGripAttachment");
		};
	})

	local chain = FABRIKChain.fromPointsConstraints(CFrame.new(), points, {
		-- FABRIKConstraint.new(math.rad(45), math.rad(45), math.rad(45), math.rad(45));
		-- FABRIKConstraint.new(math.rad(45), math.rad(45), math.rad(1), math.rad(1));
	})

	self._chain = chain
end

return ArmFABRIKBase