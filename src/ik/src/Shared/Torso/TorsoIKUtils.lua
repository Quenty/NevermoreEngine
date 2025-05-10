--[=[
	@class TorsoIKUtils
]=]

local require = require(script.Parent.loader).load(script)

local IKUtils = require("IKUtils")

local OFFSET_Y = 0.5

local TorsoIKUtils = {}

local waistYawClamper = IKUtils.getDampenedAngleClamp(math.rad(20), math.rad(10))
local waistPitchClamper = IKUtils.getDampenedAngleClamp(
	math.rad(20), -- TODO: Allow forward bend by 40 degrees
	math.rad(10)
)
local headYawClamper = IKUtils.getDampenedAngleClamp(math.rad(45), math.rad(15))
local headPitchClamper = IKUtils.getDampenedAngleClamp(math.rad(45), math.rad(15))

function TorsoIKUtils.getTargetAngles(rootPart, target)
	local baseCFrame = rootPart.CFrame * CFrame.new(0, OFFSET_Y, 0)

	local offsetWaistY = baseCFrame:pointToObjectSpace(target)
	local waistY = waistYawClamper(math.atan2(-offsetWaistY.X, -offsetWaistY.Z))

	local relativeToWaistY = baseCFrame * CFrame.Angles(0, waistY, 0)

	local headOffsetY = relativeToWaistY:pointToObjectSpace(target)
	local headY = headYawClamper(math.atan2(-headOffsetY.X, -headOffsetY.Z))

	local relativeToHeadY = relativeToWaistY * CFrame.Angles(0, headY, 0)

	local offsetWaistZ = relativeToHeadY:pointToObjectSpace(target)
	local waistZ = waistPitchClamper(math.atan2(offsetWaistZ.Y, -offsetWaistZ.Z))

	local relativeToEverything = relativeToHeadY * CFrame.Angles(0, 0, waistZ)

	local headOffsetZ = relativeToEverything:pointToObjectSpace(target)
	local headZ = headPitchClamper(math.atan2(headOffsetZ.Y, -headOffsetZ.Z))

	return waistY, headY, waistZ, headZ
end

return TorsoIKUtils
