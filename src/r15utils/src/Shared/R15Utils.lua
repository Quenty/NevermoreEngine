--!strict
--[=[
	Utility methods for R15 Characters. R15 is a specific Roblox character specification.

	@class R15Utils
]=]

local R15Utils = {}

export type R15Side = "Left" | "Right"

export type AnimationConstraintOrMotor6D = AnimationConstraint | Motor6D

--[=[
	Searches the rig for an attachment
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
]=]
function R15Utils.getRigMotor(character: Model, partName: string, motorName: string): AnimationConstraintOrMotor6D?
	assert(typeof(character) == "Instance", "Bad character")
	assert(type(partName) == "string", "Bad partName")
	assert(type(motorName) == "string", "Bad motorName")

	local basePart = R15Utils.getBodyPart(character, partName)
	if not basePart then
		return nil
	end

	local motor: any = basePart:FindFirstChild(motorName)
	if motor == nil or not (R15Utils.isAnimationConstraintOrMotor6D(motor)) then
		return nil
	end

	return motor
end

--[=[
	Determines if the instance is a Motor6D or AnimationConstraint
]=]
function R15Utils.isAnimationConstraintOrMotor6D(instance: Instance): boolean
	return instance:IsA("Motor6D") or instance:IsA("AnimationConstraint")
end

--[=[
	Retrieves the upper torso
]=]
function R15Utils.getUpperTorso(character: Model): BasePart?
	return R15Utils.getBodyPart(character, "UpperTorso")
end

--[=[
	Retrieves the lower torso
]=]
function R15Utils.getLowerTorso(character: Model): BasePart?
	return R15Utils.getBodyPart(character, "LowerTorso")
end

--[=[
	Gets a body part for a character
]=]
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
]=]
function R15Utils.getWaistJoint(character: Model): AnimationConstraintOrMotor6D?
	return R15Utils.getRigMotor(character, "UpperTorso", "Waist")
end

--[=[
	Retrieves the neck joint
]=]
function R15Utils.getNeckJoint(character: Model): AnimationConstraintOrMotor6D?
	return R15Utils.getRigMotor(character, "Head", "Neck")
end

--[=[
	Retrieves hand attachment
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
]=]
function R15Utils.getGripWeld(character: Model, side: R15Side): AnimationConstraintOrMotor6D?
	local rightHand = R15Utils.getHand(character, side)
	if rightHand == nil then
		return nil
	end

	local result: any = rightHand:FindFirstChild(R15Utils.getGripWeldName(side))
	if result == nil or not R15Utils.isAnimationConstraintOrMotor6D(result) then
		return nil
	end

	return result
end

--[=[
	Retrieves grip weld name for a given side
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
	Retrieves hand name for a given side
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
]=]
function R15Utils.getArmRigToGripLength(character: Model, side: R15Side): number?
	return R15Utils.addLengthsOrNil({
		R15Utils.getUpperArmRigLength(character, side),
		R15Utils.getLowerArmRigLength(character, side),
		R15Utils.getWristToGripLength(character, side),
	})
end

return R15Utils
