--- Utility methods for R15
-- @module R15Utils

local R15Utils = {}

function R15Utils.searchForRigAttachment(humanoid, partName, attachmentName)
	local character = humanoid.Parent
	if not character then
		return nil
	end

	local part = character:FindFirstChild(partName)
	if not part then
		return nil
	end

	return part:FindFirstChild(attachmentName)
end

function R15Utils.getUpperTorso(humanoid)
	local character = humanoid.Parent
	if not character then
		return nil
	end

	return character:FindFirstChild("UpperTorso")
end

function R15Utils.getLeftShoulderRigAttachment(humanoid)
	return R15Utils.searchForRigAttachment(humanoid, "UpperTorso", "LeftShoulderRigAttachment")
end

function R15Utils.getRightShoulderRigAttachment(humanoid)
	return R15Utils.searchForRigAttachment(humanoid, "UpperTorso", "RightShoulderRigAttachment")
end

function R15Utils.getRigLength(humanoid, partName, rigAttachment0, rigAttachment1)
	local attachment0 = R15Utils.searchForRigAttachment(humanoid, partName, rigAttachment0)
	if not attachment0 then
		return nil
	end

	local attachment1 = R15Utils.searchForRigAttachment(humanoid, partName, rigAttachment1)
	if not attachment1 then
		return nil
	end

	return (attachment0.Position - attachment1.Position).magnitude
end

function R15Utils.addLengthsOrNil(lengths)
	local total = 0
	for _, length in pairs(lengths) do
		if not length then
			return nil
		end

		total = total + length
	end

	return total
end

function R15Utils.getLeftUpperArmRigLength(humanoid)
	return R15Utils.getRigLength(humanoid, "LeftUpperArm", "LeftShoulderRigAttachment", "LeftElbowRigAttachment")
end

function R15Utils.getLeftLowerArmRigLength(humanoid)
	return R15Utils.getRigLength(humanoid, "LeftLowerArm", "LeftElbowRigAttachment", "LeftWristRigAttachment")
end

function R15Utils.getLeftWristToGripLength(humanoid)
	return R15Utils.getRigLength(humanoid, "LeftHand", "LeftWristRigAttachment", "LeftGripAttachment")
end

function R15Utils.getLeftArmRigToGripLength(humanoid)
	return R15Utils.addLengthsOrNil({
		R15Utils.getLeftUpperArmRigLength(humanoid),
		R15Utils.getLeftLowerArmRigLength(humanoid),
		R15Utils.getLeftWristToGripLength(humanoid)
	})
end

function R15Utils.getRightUpperArmRigLength(humanoid)
	return R15Utils.getRigLength(humanoid, "RightUpperArm", "RightShoulderRigAttachment", "RightElbowRigAttachment")
end

function R15Utils.getRightLowerArmRigLength(humanoid)
	return R15Utils.getRigLength(humanoid, "RightLowerArm", "RightElbowRigAttachment", "RightWristRigAttachment")
end

function R15Utils.getRightWristToGripLength(humanoid)
	return R15Utils.getRigLength(humanoid, "RightHand", "RightWristRigAttachment", "RightGripAttachment")
end

function R15Utils.getRightArmRigToGripLength(humanoid)
	return R15Utils.addLengthsOrNil({
		R15Utils.getRightUpperArmRigLength(humanoid),
		R15Utils.getRightLowerArmRigLength(humanoid),
		R15Utils.getRightWristToGripLength(humanoid)
	})
end

return R15Utils