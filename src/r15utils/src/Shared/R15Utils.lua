--[=[
	Utility methods for R15 Characters
	@class R15Utils
]=]

local R15Utils = {}

--[=[
	Searches the rig for an attachment
	@param character Model
	@param partName string
	@param attachmentName string
	@return Attachment?
]=]
function R15Utils.searchForRigAttachment(character, partName, attachmentName)
	local part = character:FindFirstChild(partName)
	if not part then
		return nil
	end

	return part:FindFirstChild(attachmentName)
end

--[=[
	Finds a rig motor
	@param character Model
	@param partName string
	@param motorName string
	@return Motor6D?
]=]
function R15Utils.getRigMotor(character, partName, motorName)
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")
	assert(type(motorName) == "string", "Bad motorName")

	local basePart = character:FindFirstChild(partName)
	if not basePart then
		return nil
	end

	local motor = basePart:FindFirstChild(motorName)
	if not motor then
		return nil
	end

	return motor
end


--[=[
	Retrieves the upper torso
	@param character Model
	@return BasePart?
]=]
function R15Utils.getUpperTorso(character)
	return character:FindFirstChild("UpperTorso")
end

--[=[
	Retrieves the lower torso
	@param character Model
	@return BasePart?
]=]
function R15Utils.getLowerTorso(character)
	return character:FindFirstChild("LowerTorso")
end

--[=[
	Retrieves the waist joint
	@param character Model
	@return Motor6D?
]=]
function R15Utils.getWaistJoint(character)
	local upperTorso = R15Utils.getUpperTorso(character)
	if not upperTorso then
		return nil
	end

	return upperTorso:FindFirstChild("Waist")
end

--[=[
	Retrieves the neck joint
	@param character Model
	@return Motor6D?
]=]
function R15Utils.getNeckJoint(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end

	return head:FindFirstChild("Neck")
end

--[=[
	Retrieves hand attachment
	@param character Model
	@param side "Left" | "Right"
	@return Attachment?
]=]
function R15Utils.getHand(character, side)
	return character:FindFirstChild(R15Utils.getHandName(side))
end

--[=[
	Retrieves grip weld
	@param character Model
	@param side "Left" | "Right"
	@return Motor6D?
]=]
function R15Utils.getGripWeld(character, side)
	local rightHand = R15Utils.getHand(character, side)
	if rightHand then
		return rightHand:FindFirstChild(R15Utils.getGripWeldName(side))
	else
		return nil
	end
end

--[=[
	Retrieves grip weld name for a given side
	@param side "Left" | "Right"
	@return "LeftGrip" | "RightGrip"
]=]
function R15Utils.getGripWeldName(side)
	if side == "Left" then
		return "LeftGrip"
	elseif side == "Right" then
		return "RightGrip"
	else
		error("Bad side")
	end
end

--[=[
	Retrieves grip weld name for a given side
	@param side "Left" | "Right"
	@return "LeftHand" | "RightHand"
]=]
function R15Utils.getHandName(side)
	if side == "Left" then
		return "LeftHand"
	elseif side == "Right" then
		return "RightHand"
	else
		error("Bad side")
	end
end

--[=[
	Retrieves the grip attachment name
	@param side "Left" | "Right"
	@return "LeftGripAttachment" | "RightGripAttachment"
]=]
function R15Utils.getGripAttachmentName(side)
	if side == "Left" then
		return "LeftGripAttachment"
	elseif side == "Right" then
		return "RightGripAttachment"
	else
		error("Bad side")
	end
end

--[=[
	Retrieves the shoulder rig attachment
	@param character Model
	@param side "Left" | "Right"
	@return Attachment?
]=]
function R15Utils.getShoulderRigAttachment(character, side)
	if side == "Left"  then
		return R15Utils.searchForRigAttachment(character, "UpperTorso", "LeftShoulderRigAttachment")
	elseif side == "Right" then
		return R15Utils.searchForRigAttachment(character, "UpperTorso", "RightShoulderRigAttachment")
	else
		error("Bad side")
	end
end

--[=[
	Retrieves the grip attachment for the given side
	@param character Model
	@param side "Left" | "Right"
	@return Attachment?
]=]
function R15Utils.getGripAttachment(character, side)
	if side == "Left"  then
		return R15Utils.searchForRigAttachment(character, "LeftHand", "LeftGripAttachment")
	elseif side == "Right" then
		return R15Utils.searchForRigAttachment(character, "RightHand", "RightGripAttachment")
	else
		error("Bad side")
	end
end

--[=[
	Retrieves the expected root part y offset for a humanoid
	@param humanoid Humanoid
	@return number?
]=]
function R15Utils.getExpectedRootPartYOffset(humanoid)
	local rootPart = humanoid.RootPart
	if not rootPart then
		return nil
	end

	return humanoid.HipHeight + rootPart.Size.Y/2
end

--[=[
	Gets the length of a segment for a rig
	@param character Model
	@param partName string
	@param rigAttachment0 string
	@param rigAttachment1 string
	@return number?
]=]
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

--[=[
	Adds the lengths together
	@param lengths { number? }
	@return number?
]=]
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

--[=[
	Retrieves the upper arm length for a character
	@param character Model
	@param side "Left" | "Right"
	@return number?
]=]
function R15Utils.getUpperArmRigLength(character, side)
	if side == "Left" then
		return R15Utils.getRigLength(character, "LeftUpperArm", "LeftShoulderRigAttachment", "LeftElbowRigAttachment")
	elseif side == "Right" then
		return R15Utils.getRigLength(character, "RightUpperArm", "RightShoulderRigAttachment", "RightElbowRigAttachment")
	else
		error("Bad side")
	end
end

--[=[
	Retrieves the lower arm length for a character
	@param character Model
	@param side "Left" | "Right"
	@return number?
]=]
function R15Utils.getLowerArmRigLength(character, side)
	if side == "Left" then
		return R15Utils.getRigLength(character, "LeftLowerArm", "LeftElbowRigAttachment", "LeftWristRigAttachment")
	elseif side == "Right" then
		return R15Utils.getRigLength(character, "RightLowerArm", "RightElbowRigAttachment", "RightWristRigAttachment")
	else
		error("Bad side")
	end
end

--[=[
	Retrieves the wrist to hand length
	@param character Model
	@param side "Left" | "Right"
	@return number?
]=]
function R15Utils.getWristToGripLength(character, side)
	if side == "Left" then
		return R15Utils.getRigLength(character, "LeftHand", "LeftWristRigAttachment", "LeftGripAttachment")
	elseif side == "Right" then
		return R15Utils.getRigLength(character, "RightHand", "RightWristRigAttachment", "RightGripAttachment")
	else
		error("Bad side")
	end
end

function R15Utils.getHumanoidScaleProperty(humanoid, scaleValueName)
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	local scaleValue = humanoid:FindFirstChild(scaleValueName)
	if scaleValue then
		return scaleValue.Value
	else
		return nil
	end
end

--[=[
	Computes the length of an arm for a given character
	@param character Model
	@param side "Left" | "Right"
	@return number?
]=]
function R15Utils.getArmRigToGripLength(character, side)
	return R15Utils.addLengthsOrNil({
		R15Utils.getUpperArmRigLength(character, side),
		R15Utils.getLowerArmRigLength(character, side),
		R15Utils.getWristToGripLength(character, side)
	})
end

return R15Utils