--- Utility methods for R15
-- @module R15Utils

local R15Utils = {}

function R15Utils.searchForRigAttachment(character, partName, attachmentName)
	local part = character:FindFirstChild(partName)
	if not part then
		return nil
	end

	return part:FindFirstChild(attachmentName)
end

function R15Utils.getUpperTorso(character)
	return character:FindFirstChild("UpperTorso")
end

function R15Utils.getLowerTorso(character)
	return character:FindFirstChild("LowerTorso")
end

function R15Utils.getWaistJoint(character)
	local upperTorso = R15Utils.getUpperTorso(character)
	if not upperTorso then
		return nil
	end

	return upperTorso:FindFirstChild("Waist")
end

function R15Utils.getNeckJoint(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end

	return head:FindFirstChild("Neck")
end


function R15Utils.getLeftGripAttachment(character)
	return R15Utils.searchForRigAttachment(character, "LeftHand", "LeftGripAttachment")
end

function R15Utils.getRightGripAttachment(character)
	return R15Utils.searchForRigAttachment(character, "RightHand", "RightGripAttachment")
end

function R15Utils.getLeftShoulderRigAttachment(character)
	return R15Utils.searchForRigAttachment(character, "UpperTorso", "LeftShoulderRigAttachment")
end

function R15Utils.getRightShoulderRigAttachment(character)
	return R15Utils.searchForRigAttachment(character, "UpperTorso", "RightShoulderRigAttachment")
end

function R15Utils.getExpectedRootPartYOffset(humanoid)
	local rootPart = humanoid.RootPart
	if not rootPart then
		return nil
	end

	return humanoid.HipHeight + rootPart.Size.Y/2
end

function R15Utils.getRigLength(character, partName, rigAttachment0, rigAttachment1)
	local attachment0 = R15Utils.searchForRigAttachment(character, partName, rigAttachment0)
	if not attachment0 then
		return nil
	end

	local attachment1 = R15Utils.searchForRigAttachment(character, partName, rigAttachment1)
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

function R15Utils.getLeftUpperArmRigLength(character)
	return R15Utils.getRigLength(character, "LeftUpperArm", "LeftShoulderRigAttachment", "LeftElbowRigAttachment")
end

function R15Utils.getLeftLowerArmRigLength(character)
	return R15Utils.getRigLength(character, "LeftLowerArm", "LeftElbowRigAttachment", "LeftWristRigAttachment")
end

function R15Utils.getLeftWristToGripLength(character)
	return R15Utils.getRigLength(character, "LeftHand", "LeftWristRigAttachment", "LeftGripAttachment")
end

function R15Utils.getLeftArmRigToGripLength(character)
	return R15Utils.addLengthsOrNil({
		R15Utils.getLeftUpperArmRigLength(character),
		R15Utils.getLeftLowerArmRigLength(character),
		R15Utils.getLeftWristToGripLength(character)
	})
end

function R15Utils.getRightUpperArmRigLength(character)
	return R15Utils.getRigLength(character, "RightUpperArm", "RightShoulderRigAttachment", "RightElbowRigAttachment")
end

function R15Utils.getRightLowerArmRigLength(character)
	return R15Utils.getRigLength(character, "RightLowerArm", "RightElbowRigAttachment", "RightWristRigAttachment")
end

function R15Utils.getRightWristToGripLength(character)
	return R15Utils.getRigLength(character, "RightHand", "RightWristRigAttachment", "RightGripAttachment")
end

function R15Utils.getRightArmRigToGripLength(character)
	return R15Utils.addLengthsOrNil({
		R15Utils.getRightUpperArmRigLength(character),
		R15Utils.getRightLowerArmRigLength(character),
		R15Utils.getRightWristToGripLength(character)
	})
end

return R15Utils