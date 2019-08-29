--- Torso resources for IK
-- @classmod TorsoIK
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local IKAngleCalculator = require("IKAngleCalculator")
local Signal = require("Signal")
local BaseObject = require("BaseObject")

local TorsoIK = setmetatable({}, BaseObject)
TorsoIK.__index = TorsoIK
TorsoIK.ClassName = "TorsoIK"

function TorsoIK.new(lowerTorso, upperTorso, waist, neck)
	local self = setmetatable(BaseObject.new(), TorsoIK)

	self.Pointed = Signal.new() -- :Fire(position)
	self._maid:GiveTask(self.Pointed)

	self._lowerTorso = lowerTorso or error("No lowerTorso")
	self._upperTorso = upperTorso or error("No upperTorso")
	self._waist = waist or error("No waist")
	self._neck = neck or error("No neck")

	self._waistYCalculator = IKAngleCalculator.new(40)
	self._waistYCalculator.Min = math.rad(12)
	self._waistYCalculator.BounceRange = math.rad(90)
	self._waistYCalculator.BounceAmount = math.rad(18)

	self._waistZCalculator = IKAngleCalculator.new(30)
	self._waistZCalculator.Min = math.rad(25)
	self._waistZCalculator.BounceRange = math.rad(9)
	self._waistZCalculator.BounceAmount = math.rad(9)

	self.HeadYCalculator = IKAngleCalculator.new(60)
	self.HeadYCalculator.Min = math.rad(30)
	self.HeadYCalculator.BounceRange = math.rad(30)
	self.HeadYCalculator.BounceAmount = math.rad(30)

	self.HeadZCalculator = IKAngleCalculator.new(24)
	self.HeadZCalculator.Min = math.rad(15)
	self.HeadZCalculator.BounceRange = math.rad(30)
	self.HeadZCalculator.BounceAmount = math.rad(20)

	return self
end

function TorsoIK:UpdateTransformOnly()
	if not self._relWaistTransform or not self._relNeckTransform then
		return
	end

	self._waist.Transform = self._waist.Transform * self._relWaistTransform
	self._neck.Transform = self._neck.Transform * self._relNeckTransform
end

function TorsoIK:Update()
	self._relWaistTransform = CFrame.Angles(0, self._waistYCalculator.RenderAngle, 0)
		* CFrame.Angles(self._waistZCalculator.RenderAngle, 0, 0)
	self._relNeckTransform = CFrame.Angles(0, self.HeadYCalculator.RenderAngle, 0)
		* CFrame.Angles(self.HeadZCalculator.RenderAngle, 0, 0)

	self:UpdateTransformOnly()
end

function TorsoIK:GetTarget()
	return self._target -- May return nil
end

function TorsoIK:Point(position)
	self._target = position

	local waist = self._waist
	local offset = (self._lowerTorso.CFrame * waist.C0):pointToObjectSpace(position)
	self._waistYCalculator.Target = math.atan2(-offset.X, -offset.Z)
	self._waistZCalculator.Target = math.atan2(offset.Y, -offset.Z)

	self.HeadYCalculator.Target = math.atan2(-offset.X, -offset.Z)
	self.HeadZCalculator.Target = math.atan2(offset.Y, -offset.Z)

	self.Pointed:Fire(self._target)
end

--- Helper method used for other IK
function TorsoIK:GetTargetUpperTorsoCFrame()
	local waist = self._waist

	local estimated_transform = waist.Transform
		* CFrame.Angles(0, self._waistYCalculator.Target, 0)
		* CFrame.Angles(self._waistZCalculator.Target, 0, 0)

	return self._lowerTorso.CFrame * waist.C0 * estimated_transform * waist.C1:inverse()
end

function TorsoIK:GetUpperTorsoCFrame()
	return self._upperTorso.CFrame
end

return TorsoIK