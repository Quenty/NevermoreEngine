--- Provides IK for a given arm
-- @classmod ArmFABRIKBase

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local Workspace = game:GetService("Workspace")

local BaseObject = require("BaseObject")
local IKResource = require("IKResource")
local IKResourceUtils = require("IKResourceUtils")
local FABRIKUtils = require("FABRIKUtils")
local FABRIKChain = require("FABRIKChain")
local FABRIKElbowConstraint = require("FABRIKElbowConstraint")
local FABRIKShoulderConstraint = require("FABRIKShoulderConstraint")
local IKAimPositionPriorites = require("IKAimPositionPriorites")
local FABRIKHandConstraint = require("FABRIKHandConstraint")

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
	while self._grips[i] and self._grips[i].priority > priority do
		i = i + 1
	end

	table.insert(self._grips, i, gripData)

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
	local baseCFrame = self:_getBaseCFrame()
	local relTarget = baseCFrame:pointToObjectSpace(worldPosition)

	self._chain:SetTarget(relTarget)
	self._chain:Solve()

	local bones = self._chain:GetBones()

	if game:GetService("RunService"):IsClient() then
		self._drawer = self._drawer or require("Drawer").new()
		self._drawer:Clear()
		for key, item in pairs(self._chain:GetPoints()) do
			self._maid[key .. "pt"] = require("Draw").point(baseCFrame:pointToWorldSpace(item), nil, nil, 0.1)
		end

		-- self._resources:Get("Hand").Transparency = 0.7
		-- self._resources:Get("UpperArm").Transparency = 0.7
		-- self._resources:Get("LowerArm").Transparency = 0.7
	-- 	-- self._drawer:CFrame(baseCFrame, Workspace)

	-- 	-- self._drawer:CFrame(baseCFrame * bones[1]:GetCFrame(), Workspace)
	-- 	-- self._drawer:CFrame(baseCFrame * bones[2]:GetCFrame(), Workspace)
	-- 	-- self._drawer:CFrame(baseCFrame * bones[3]:GetCFrame(), Workspace)
	end

	local function projectCFrame(attachment1, attachment2)
		return attachment1.CFrame:inverse() * attachment2.CFrame
	end

	local function getBoneCFrame(bone, worldCFrame, targetAttachmentRelativeToBoneCFrame)
		local alignedCFrame = bone:GetAlignedCFrame()

		local relativeOffset = alignedCFrame:vectorToWorldSpace(targetAttachmentRelativeToBoneCFrame * Vector3.new(1, 1, 0))

		local alignedCFrameWorld = baseCFrame:toWorldSpace(bone:GetAlignedOffsetCFrame(-relativeOffset))
		local relative = worldCFrame:toObjectSpace(alignedCFrameWorld)

		if self._drawer then
			local rel = baseCFrame * bone:GetCFrame()
			self._drawer:CFrame(rel - rel.p + worldCFrame.p, Workspace)
		end

		return relative - relative.p
	end

	local upperShoulderRigAttachment = self._resources:Get("UpperTorsoShoulderRigAttachment")

	local shoulderCFrame = upperShoulderRigAttachment.WorldCFrame
	local upperArmProjection = projectCFrame(
				self._resources:Get("UpperArmShoulderRigAttachment"),
				self._resources:Get("UpperArmElbowRigAttachment"))
	local shoulderTransform = getBoneCFrame(bones[1], shoulderCFrame, (CFA_90X * upperArmProjection).p) * CFA_90X

	local elbowCFrame = shoulderCFrame * shoulderTransform * upperArmProjection
	local lowerArmProjection = projectCFrame(
				self._resources:Get("LowerArmElbowRigAttachment"),
				self._resources:Get("LowerArmWristRigAttachment"))
	local elbowTransform = getBoneCFrame(bones[2], elbowCFrame, (CFA_90X * lowerArmProjection).p) * CFA_90X
	local wristCFrame = elbowCFrame * elbowTransform * lowerArmProjection

	local handProjection = projectCFrame(
				self._resources:Get("HandWristRigAttachment"),
				self._resources:Get("HandGripAttachment"))
	local wristTransform = getBoneCFrame(bones[3], wristCFrame, (CFA_90X * handProjection).p) * CFA_90X

	self._shoulderTransform = shoulderTransform
	self._elbowTransform = elbowTransform
	self._wristTransform = wristTransform
end

function ArmFABRIKBase:_getBaseCFrame()
	-- snapshot our system as is
	local upperShoulderRigAttachment = self._resources:Get("UpperTorsoShoulderRigAttachment")
	local baseCFrame = upperShoulderRigAttachment.WorldCFrame

	return baseCFrame
end

function ArmFABRIKBase:_rebuildChain()
	if not self._resources:IsReady() then
		return
	end

	local baseCFrame = self:_getBaseCFrame()

	local points, offsets = FABRIKUtils.pointsFromAttachment(baseCFrame, {
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
		FABRIKShoulderConstraint.new();
		FABRIKElbowConstraint.new();
		FABRIKHandConstraint.new();
		-- FABRIKConstraint.new(math.rad(1), math.rad(1), math.rad(1), math.rad(1));
		-- FABRIKConstraint.new(math.rad(1), math.rad(1), math.rad(1), math.rad(1));
		-- FABRIKConstraint.new(math.rad(80), math.rad(80), math.rad(10), math.rad(10));
		-- FABRIKConstraint.new(math.rad(80), math.rad(80), math.rad(10), math.rad(10));
		-- FABRIKConstraint.new(math.rad(80), math.rad(80), math.rad(10), math.rad(10));
	}, offsets)

	self._chain = chain
end

return ArmFABRIKBase