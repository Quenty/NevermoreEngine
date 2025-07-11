--!strict
--[=[
	Utility methods for R15 Characters. R15 is a specific Roblox character specification.

	@class R15Utils
]=]

local R15Utils = {}

export type R15Side = "Left" | "Right"

--[=[
	Searches the rig for an attachment
	@param character Model
	@param partName string
	@param attachmentName string
	@return Attachment?
]=]
function R15Utils.searchForRigAttachment(character: Model, partName: string, attachmentName: string): Attachment?
	local part = R15Utils.getBodyPart(character, partName)
	if not part then
		return nil
	end

	local result = part:FindFirstChild(attachmentName)
	if result == nil or not result:IsA("Attachment") then
		return nil
	end

	return result
end

--[=[
	Finds a rig motor
	@param character Model
	@param partName string
	@param motorName string
	@return Motor6D?
]=]
function R15Utils.getRigMotor(character: Model, partName: string, motorName: string): Motor6D?
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")
	assert(type(motorName) == "string", "Bad motorName")

	local basePart = R15Utils.getBodyPart(character, partName)
	if not basePart then
		return nil
	end

	local motor = basePart:FindFirstChild(motorName)
	if motor == nil or not motor:IsA("Motor6D") then
		return nil
	end

	return motor
end

--[=[
	Retrieves the upper torso
	@param character Model
	@return BasePart?
]=]
function R15Utils.getUpperTorso(character: Model): BasePart?
	return R15Utils.getBodyPart(character, "UpperTorso")
end

--[=[
	Retrieves the lower torso
	@param character Model
	@return BasePart?
]=]
function R15Utils.getLowerTorso(character: Model): BasePart?
	return R15Utils.getBodyPart(character, "LowerTorso")
end

function R15Utils.getBodyPart(character: Model, partName: string): BasePart?
	local found = character:FindFirstChild(partName)
	if found == nil then
		return nil
	end

	if not found:IsA("BasePart") then
		return nil
	end

	return found
end

--[=[
	Retrieves the waist joint
	@param character Model
	@return Motor6D?
]=]
function R15Utils.getWaistJoint(character: Model): Motor6D?
	return R15Utils.getRigMotor(character, "UpperTorso", "Waist")
end

--[=[
	Retrieves the neck joint
	@param character Model
	@return Motor6D?
]=]
function R15Utils.getNeckJoint(character: Model): Motor6D?
	return R15Utils.getRigMotor(character, "Head", "Neck")
end

--[=[
	Retrieves hand attachment
	@param character Model
	@param side "Left" | "Right"
	@return BasePart?
]=]
function R15Utils.getHand(character: Model, side: R15Side): BasePart?
	local result = character:FindFirstChild(R15Utils.getHandName(side))
	if result == nil or not result:IsA("BasePart") then
		return nil
	end

	return result
end

--[=[
	Retrieves grip weld
	@param character Model
	@param side "Left" | "Right"
	@return Motor6D?
]=]
function R15Utils.getGripWeld(character: Model, side: R15Side): Motor6D?
	local rightHand = R15Utils.getHand(character, side)
	if rightHand == nil then
		return nil
	end

	local result = rightHand:FindFirstChild(R15Utils.getGripWeldName(side))
	if result == nil or not result:IsA("Motor6D") then
		return nil
	end

	return result
end

--[=[
	Retrieves grip weld name for a given side
	@param side "Left" | "Right"
	@return "LeftGrip" | "RightGrip"
]=]
function R15Utils.getGripWeldName(side: R15Side): "LeftGrip" | "RightGrip"
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
function R15Utils.getHandName(side: R15Side): "LeftHand" | "RightHand"
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
function R15Utils.getGripAttachmentName(side: R15Side): "LeftGripAttachment" | "RightGripAttachment"
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
function R15Utils.getShoulderRigAttachment(character: Model, side: R15Side): Attachment?
	if side == "Left" then
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
function R15Utils.getGripAttachment(character: Model, side: R15Side): Attachment?
	if side == "Left" then
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
function R15Utils.getExpectedRootPartYOffset(humanoid: Humanoid): number?
	local rootPart = humanoid.RootPart
	if not rootPart then
		return nil
	end

	return humanoid.HipHeight + rootPart.Size.Y / 2
end

--[=[
	Gets the length of a segment for a rig
	@param character Model
	@param partName string
	@param rigAttachment0 string
	@param rigAttachment1 string
	@return number?
]=]
function R15Utils.getRigLength(
	character: Model,
	partName: string,
	rigAttachment0: string,
	rigAttachment1: string
): number?
	local attachment0 = R15Utils.searchForRigAttachment(character, partName, rigAttachment0)
	if not attachment0 then
		return nil
	end

	local attachment1 = R15Utils.searchForRigAttachment(character, partName, rigAttachment1)
	if not attachment1 then
		return nil
	end

	return (attachment0.Position - attachment1.Position).Magnitude
end

--[=[
	Adds the lengths together
	@param lengths { number? }
	@return number?
]=]
function R15Utils.addLengthsOrNil(lengths: { number? }): number?
	local total = 0
	for _, length in lengths do
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
function R15Utils.getUpperArmRigLength(character: Model, side: R15Side): number?
	if side == "Left" then
		return R15Utils.getRigLength(character, "LeftUpperArm", "LeftShoulderRigAttachment", "LeftElbowRigAttachment")
	elseif side == "Right" then
		return R15Utils.getRigLength(
			character,
			"RightUpperArm",
			"RightShoulderRigAttachment",
			"RightElbowRigAttachment"
		)
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
function R15Utils.getLowerArmRigLength(character: Model, side: R15Side): number?
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
function R15Utils.getWristToGripLength(character: Model, side: R15Side): number?
	if side == "Left" then
		return R15Utils.getRigLength(character, "LeftHand", "LeftWristRigAttachment", "LeftGripAttachment")
	elseif side == "Right" then
		return R15Utils.getRigLength(character, "RightHand", "RightWristRigAttachment", "RightGripAttachment")
	else
		error("Bad side")
	end
end

--[=[
	Retrieves the humanoid scale property
	@param humanoid Humanoid
	@param scaleValueName string
	@return number?
]=]
function R15Utils.getHumanoidScaleProperty(humanoid: Humanoid, scaleValueName: string): number?
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	local scaleValue = humanoid:FindFirstChild(scaleValueName)
	if scaleValue and scaleValue:IsA("NumberValue") then
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
function R15Utils.getArmRigToGripLength(character: Model, side: R15Side): number?
	return R15Utils.addLengthsOrNil({
		R15Utils.getUpperArmRigLength(character, side),
		R15Utils.getLowerArmRigLength(character, side),
		R15Utils.getWristToGripLength(character, side),
	})
end

return R15Utils
