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

function R15Utils.getHand(character, side)
	return character:FindFirstChild(R15Utils.getHandName(side))
end

function R15Utils.getGripWeld(character, side)
	local rightHand = R15Utils.getHand(character, side)
	if rightHand then
		return rightHand:FindFirstChild(R15Utils.getGripWeldName(side))
	else
		return nil
	end
end

function R15Utils.getGripWeldName(side)
	if side == "Left" then
		return "LeftGrip"
	elseif side == "Right" then
		return "RightGrip"
	else
		error("Bad side")
	end
end

function R15Utils.getHandName(side)
	if side == "Left" then
		return "LeftHand"
	elseif side == "Right" then
		return "RightHand"
	else
		error("Bad side")
	end
end

function R15Utils.getGripAttachmentName(side)
	if side == "Left" then
		return "LeftGripAttachment"
	elseif side == "Right" then
		return "RightGripAttachment"
	else
		error("Bad side")
	end
end

function R15Utils.getShoulderRigAttachment(character, side)
	if side == "Left"  then
		return R15Utils.searchForRigAttachment(character, "UpperTorso", "LeftShoulderRigAttachment")
	elseif side == "Right" then
		return R15Utils.searchForRigAttachment(character, "UpperTorso", "RightShoulderRigAttachment")
	else
		error("Bad side")
	end
end

function R15Utils.getGripAttachment(character, side)
	if side == "Left"  then
		return R15Utils.searchForRigAttachment(character, "LeftHand", "LeftGripAttachment")
	elseif side == "Right" then
		return R15Utils.searchForRigAttachment(character, "RightHand", "RightGripAttachment")
	else
		error("Bad side")
	end
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

function R15Utils.getUpperArmRigLength(character, side)
	if side == "Left" then
		return R15Utils.getRigLength(character, "LeftUpperArm", "LeftShoulderRigAttachment", "LeftElbowRigAttachment")
	elseif side == "Right" then
		return R15Utils.getRigLength(character, "RightUpperArm", "RightShoulderRigAttachment", "RightElbowRigAttachment")
	else
		error("Bad side")
	end
end

function R15Utils.getLowerArmRigLength(character, side)
	if side == "Left" then
		return R15Utils.getRigLength(character, "LeftLowerArm", "LeftElbowRigAttachment", "LeftWristRigAttachment")
	elseif side == "Right" then
		return R15Utils.getRigLength(character, "RightLowerArm", "RightElbowRigAttachment", "RightWristRigAttachment")
	else
		error("Bad side")
	end
end

function R15Utils.getWristToGripLength(character, side)
	if side == "Left" then
		return R15Utils.getRigLength(character, "LeftHand", "LeftWristRigAttachment", "LeftGripAttachment")
	elseif side == "Right" then
		return R15Utils.getRigLength(character, "RightHand", "RightWristRigAttachment", "RightGripAttachment")
	else
		error("Bad side")
	end
end

function R15Utils.getArmRigToGripLength(character, side)
	return R15Utils.addLengthsOrNil({
		R15Utils.getUpperArmRigLength(character, side),
		R15Utils.getLowerArmRigLength(character, side),
		R15Utils.getWristToGripLength(character, side)
	})
end

return R15Utils