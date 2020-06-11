--- Provides IK for a given arm
-- @classmod ArmIKBase

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local Math = require("Math")
local IKResourceUtils = require("IKResourceUtils")
local IKResource = require("IKResource")
local IKAimPositionPriorites = require("IKAimPositionPriorites")

local CFA_90X = CFrame.Angles(math.pi/2, 0, 0)

local ArmIKBase = setmetatable({}, BaseObject)
ArmIKBase.ClassName = "ArmIKBase"
ArmIKBase.__index = ArmIKBase

function ArmIKBase.new(humanoid, armName)
	local self = setmetatable(BaseObject.new(), ArmIKBase)

	self._humanoid = humanoid or error("No humanoid")

	self._grips = {}

	self._resources = IKResource.new(IKResourceUtils.createResource({
		name = "Character";
		robloxName = self._humanoid.Parent.Name;
		children = {
			IKResourceUtils.createResource({
				name = "UpperArm";
				robloxName = armName .. "UpperArm";
				children = {
					IKResourceUtils.createResource({
						name = "Shoulder";
						robloxName = armName .. "Shoulder";
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
						name = "HandGripAttachment";
						robloxName = armName .. "GripAttachment";
					});
				};
			});
		}
	}))
	self._maid:GiveTask(self._resources)
	self._resources:SetInstance(self._humanoid.Parent or error("No humanoid.Parent"))

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
end

-- Sets transform
function ArmIKBase:UpdateTransformOnly()
	if not self._grips[1] then
		return
	end
	if not self._shoulderTransform or not self._elbowTransform then
		return
	end
	if not self._resources:IsReady() then
		return
	end

	local shoulder = self._resources:Get("Shoulder")
	local elbow = self._resources:Get("Elbow")

	shoulder.Transform = self._shoulderTransform
	elbow.Transform = self._elbowTransform
end

function ArmIKBase:Update()
	if self:_updatePoint() then
		local shoulderXAngle = self._shoulderXAngle
		local elbowXAngle = self._elbowXAngle

		local yrot = CFrame.new(Vector3.new(), self._offset)

		self._shoulderTransform = (yrot * CFA_90X * CFrame.Angles(shoulderXAngle, 0, 0)) --:inverse()
		self._elbowTransform = CFrame.Angles(elbowXAngle, 0, 0)

		self:UpdateTransformOnly()
	end
end

function ArmIKBase:_updatePoint()
	local grip = self._grips[1]
	if not grip then
		self:_clear()
		return false
	end

	if not self:_calculatePoint(grip.attachment.WorldPosition) then
		self:_clear()
		return false
	end

	return true
end

function ArmIKBase:_clear()
	self._offset = nil
	self._elbowTransform = nil
	self._shoulderTransform = nil
end

function ArmIKBase:_calculatePoint(targetPositionWorld)
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

	local base = shoulder.Part0.CFrame * shoulder.C0
	local elbowCFrame = elbow.Part0.CFrame * elbow.C0
	local wristCFrame = elbow.Part1.CFrame * wrist.C0

	local r0 = (base.p - elbowCFrame.p).Magnitude
	local r1 = (elbowCFrame.p - wristCFrame.p).Magnitude

	r1 = r1 + (gripAttachment.WorldPosition - wristCFrame.p).Magnitude

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

return ArmIKBase