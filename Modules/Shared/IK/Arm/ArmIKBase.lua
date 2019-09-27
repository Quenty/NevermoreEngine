--- Provides IK for a given arm
-- @classmod ArmIKBase

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local Math = require("Math")

local CFA_90X = CFrame.Angles(math.pi/2, 0, 0)

local ArmIKBase = setmetatable({}, BaseObject)
ArmIKBase.ClassName = "ArmIKBase"
ArmIKBase.__index = ArmIKBase

function ArmIKBase.new(gripAttachment, shoulder, elbow, wrist)
	local self = setmetatable(BaseObject.new(), ArmIKBase)

	self._gripAttachment = gripAttachment or error("No gripAttachment")
	self._shoulder = shoulder or error("No shoulder")
	self._elbow = elbow or error("No elbow")
	self._wrist = wrist or error("No wrist")

	self._grips = {}

	return self
end

function ArmIKBase:Grip(attachment, priority)
	local gripData = {
		attachment = attachment;
		priority = priority;
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

	self._shoulder.Transform = self._shoulderTransform
	self._elbow.Transform = self._elbowTransform
end

function ArmIKBase:Update()
	self:_updatePoint()

	local offsetValue = self._offset
	if not (offsetValue and offsetValue.Magnitude > 0) then
		return
	end

	local shoulderXAngle = self._shoulderXAngle
	local elbowXAngle = self._elbowXAngle

	local yrot = CFrame.new(Vector3.new(), offsetValue)

	self._shoulderTransform = (yrot * CFA_90X * CFrame.Angles(shoulderXAngle, 0, 0)) --:inverse()
	self._elbowTransform = CFrame.Angles(elbowXAngle, 0, 0)

	self:UpdateTransformOnly()
end

function ArmIKBase:_updatePoint()
	local grip = self._grips[1]
	if not grip then
		self:_clear()
		return
	end

	self:_calculatePoint(grip.attachment.WorldPosition)
end

function ArmIKBase:_clear()
	self._offset = nil
	self._elbowTransform = nil
	self._shoulderTransform = nil
end

function ArmIKBase:_calculatePoint(targetPositionWorld)
	local shoulder = self._shoulder
	local elbow = self._elbow
	local wrist = self._wrist

	local base = shoulder.Part0.CFrame * shoulder.C0
	local elbowCFrame = elbow.Part0.CFrame * elbow.C0
	local wristCFrame = elbow.Part1.CFrame * wrist.C0

	local r0 = (base.p - elbowCFrame.p).Magnitude
	local r1 = (elbowCFrame.p - wristCFrame.p).Magnitude

	r1 = r1 + (self._gripAttachment.WorldPosition - wristCFrame.p).Magnitude

	local offset = base:pointToObjectSpace(targetPositionWorld)
	local d = offset.Magnitude

	if d > (r0 + r1) then -- Case: Circles are seperate
		d = r0 + r1
	end

	local baseAngle = Math.lawOfCosines(r0, d, r1)
	local elbowAngle = Math.lawOfCosines(r1, r0, d) -- Solve for angle across from d

	if not (baseAngle and elbowAngle) then
		return
	end

	elbowAngle = (elbowAngle - math.pi)
	if elbowAngle > -math.pi/32 then -- Force a bit of bent elbow
		elbowAngle = -math.pi/32
	end

	self._shoulderXAngle = -baseAngle
	self._elbowXAngle = -elbowAngle

	self._offset = offset.unit * d
end

return ArmIKBase