---
-- @module TorsoIKUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local IKUtils = require("IKUtils")

local OFFSET_Y = 0.5

local TorsoIKUtils = {}

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

function TorsoIKUtils.getTargetAngles(rootPart, target)
	local baseCFrame = rootPart.CFrame
		* CFrame.new(0, OFFSET_Y, 0)

	local offsetWaistY = baseCFrame:pointToObjectSpace(target)
	local waistY = waistYClamper(math.atan2(-offsetWaistY.X, -offsetWaistY.Z))

	local relativeToWaistY = baseCFrame
		* CFrame.Angles(0, waistY, 0)

	local headOffsetY = relativeToWaistY:pointToObjectSpace(target)
	local headY = headYClamper(math.atan2(-headOffsetY.X, -headOffsetY.Z))

	local relativeToHeadY = relativeToWaistY
		* CFrame.Angles(0, headY, 0)

	local offsetWaistZ = relativeToHeadY:pointToObjectSpace(target)
	local waistZ = waistZClamper(math.atan2(offsetWaistZ.Y, -offsetWaistZ.Z))

	local relativeToEverything = relativeToHeadY
		* CFrame.Angles(0, 0, waistZ)

	local headOffsetZ = relativeToEverything:pointToObjectSpace(target)
	local headZ = headZClamper(math.atan2(headOffsetZ.Y, -headOffsetZ.Z))

	return waistY, headY, waistZ, headZ
end

return TorsoIKUtils