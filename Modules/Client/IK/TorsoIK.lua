--- Torso resources for IK
-- @classmod TorsoIK
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local AccelTween = require("AccelTween")
local IKUtils = require("IKUtils")
local Signal = require("Signal")
local BaseObject = require("BaseObject")

local waistYClamper = IKUtils.getDampenedAngleClamp(
		math.rad(45),
		math.rad(15))
local waistZClamper = IKUtils.getDampenedAngleClamp(
		math.rad(20),
		math.rad(10))
local headYClamper = IKUtils.getDampenedAngleClamp(
		math.rad(90),
		math.rad(30))
local headZClamper = IKUtils.getDampenedAngleClamp(
		math.rad(60),
		math.rad(15))

local ROOT_PART_TO_WAIST_DIST_ESTIMATE = -1

local TorsoIK = setmetatable({}, BaseObject)
TorsoIK.__index = TorsoIK
TorsoIK.ClassName = "TorsoIK"

function TorsoIK.new(rootPart, lowerTorso, upperTorso, waist, neck)
	local self = setmetatable(BaseObject.new(), TorsoIK)

	self.Pointed = Signal.new() -- :Fire(position)
	self._maid:GiveTask(self.Pointed)

	self._rootPart = rootPart or error("No rootPart")
	self._lowerTorso = lowerTorso or error("No lowerTorso")
	self._upperTorso = upperTorso or error("No upperTorso")
	self._waist = waist or error("No waist")
	self._neck = neck or error("No neck")

	self._waistY = AccelTween.new(40)
	self._waistZ = AccelTween.new(30)

	self._headY = AccelTween.new(60)
	self._headZ = AccelTween.new(40)

	self._lastValidWaistTransform = self._waist.Transform
	self._lastWaistTransform = self._waist.Transform

	self._lastValidNeckTransform = self._neck.Transform
	self._lastNeckTransform = self._neck.Transform

	return self
end

function TorsoIK:UpdateTransformOnly()
	if not self._relWaistTransform or not self._relNeckTransform then
		return
	end

	-- Waist:
	local currentWaistTransform = self._waist.Transform
	if self._lastWaistTransform ~= currentWaistTransform then
		self._lastValidWaistTransform = currentWaistTransform
	end
	self._waist.Transform = self._lastValidWaistTransform * self._relWaistTransform
	self._lastWaistTransform = self._waist.Transform -- NOTE: Have to read this from the weld, otherwise comparison is off

	-- Neck:
	local currentNeckTransform = self._neck.Transform
	if self._lastNeckTransform ~= currentNeckTransform then
		self._lastValidNeckTransform = currentNeckTransform
	end
	self._neck.Transform = self._lastValidNeckTransform * self._relNeckTransform
	self._lastNeckTransform = self._neck.Transform -- NOTE: Have to read this from the weld, otherwise comparison is off
end

function TorsoIK:Update()
	self._relWaistTransform = CFrame.Angles(0, self._waistY.p, 0)
		* CFrame.Angles(self._waistZ.p, 0, 0)
	self._relNeckTransform = CFrame.Angles(0, self._headY.p, 0)
		* CFrame.Angles(self._headZ.p, 0, 0)

	self:UpdateTransformOnly()
end

function TorsoIK:GetTarget()
	return self._target -- May return nil
end

function TorsoIK:Point(position)
	self._target = position

	local baseCFrame = self._rootPart.CFrame
		* CFrame.new(0, ROOT_PART_TO_WAIST_DIST_ESTIMATE, 0)

	local offsetWaistY = baseCFrame:pointToObjectSpace(self._target)
	self._waistY.t = waistYClamper(math.atan2(-offsetWaistY.X, -offsetWaistY.Z))

	local relativeToWaistY = baseCFrame
		* CFrame.Angles(0, self._waistY.t, 0)

	local headOffsetY = relativeToWaistY:pointToObjectSpace(self._target)
	self._headY.t = headYClamper(math.atan2(-headOffsetY.X, -headOffsetY.Z))

	local relativeToHeadY = relativeToWaistY
		* CFrame.Angles(0, self._headY.t, 0)

	local offsetWaistZ = relativeToHeadY:pointToObjectSpace(self._target)
	self._waistZ.t = waistZClamper(math.atan2(offsetWaistZ.Y, -offsetWaistZ.Z))

	local relativeToEverything = relativeToHeadY
		* CFrame.Angles(0, 0, self._waistZ.t)

	local headOffsetZ = relativeToEverything:pointToObjectSpace(self._target)
	self._headZ.t = headZClamper(math.atan2(headOffsetZ.Y, -headOffsetZ.Z))

	self.Pointed:Fire(self._target)
end

--- Helper method used for other IK
function TorsoIK:GetTargetUpperTorsoCFrame()
	local waist = self._waist

	local estimated_transform = self._lastValidWaistTransform
		* CFrame.Angles(0, self._waistYCalculator.Target, 0)
		* CFrame.Angles(self._waistZCalculator.Target, 0, 0)

	return self._lowerTorso.CFrame * waist.C0 * estimated_transform * waist.C1:inverse()
end

function TorsoIK:GetUpperTorsoCFrame()
	return self._upperTorso.CFrame
end

return TorsoIK