---
-- @classmod TempTorsoIK
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local TorsoIKUtils = require("TorsoIKUtils")
local R15Utils = require("R15Utils")

local TempTorsoIK = {}
TempTorsoIK.ClassName = "TempTorsoIK"
TempTorsoIK.__index = TempTorsoIK

function TempTorsoIK.new(ikRig)
	local self = setmetatable({}, TempTorsoIK)

	self._ikRig = ikRig or error("No ikRig")
	self._humanoid = self._ikRig:GetHumanoid()

	return self
end

function TempTorsoIK:GetTargetLeftShoulderCFrame()
	local leftShoulder = R15Utils.getLeftShoulderRigAttachment(self._humanoid.Parent)
	if not leftShoulder then
		warn("[TempTorsoIK.GetTargetLeftShoulderCFrame] - No leftShoulder")
		return nil
	end

	local upperTorsoCFrame = self:GetTargetUpperTorsoCFrame()
	if not upperTorsoCFrame then
		return nil
	end

	return upperTorsoCFrame:pointToWorldSpace(leftShoulder.Position)
end

function TempTorsoIK:GetTargetRightShoulderCFrame()
	local rightShoulder = R15Utils.getRightShoulderRigAttachment(self._humanoid.Parent)
	if not rightShoulder then
		warn("[TempTorsoIK.GetTargetRightShoulderCFrame] - No rightShoulder")
		return nil
	end

	local upperTorsoCFrame = self:GetTargetUpperTorsoCFrame()
	if not upperTorsoCFrame then
		return nil
	end

	return upperTorsoCFrame:pointToWorldSpace(rightShoulder.Position)
end

function TempTorsoIK:GetTargetUpperTorsoCFrame()
	local target = self._ikRig:GetTarget()
	if not target then
		warn("[TempTorsoIK._apply] - No target")
		return nil
	end

	local rootPart = self._humanoid.RootPart
	if not rootPart then
		warn("[TempTorsoIK._apply] - No rootPart")
		return nil
	end

	local lowerTorso = R15Utils.getLowerTorso(self._humanoid.Parent)
	if not lowerTorso then
		warn("[TempTorsoIK._apply] - No lowerTorso")
		return nil
	end

	local waist = R15Utils.getWaistJoint(self._humanoid.Parent)
	if not waist then
		warn("[TempTorsoIK._apply] - No waist")
		return nil
	end

	local waistY, _, waistZ, _ = TorsoIKUtils.getTargetAngles(rootPart, target)

	local estimated_transform = waist.Transform
		* CFrame.Angles(0, waistY, 0)
		* CFrame.Angles(waistZ, 0, 0)

	return lowerTorso.CFrame * waist.C0 * estimated_transform * waist.C1:inverse()
end

return TempTorsoIK