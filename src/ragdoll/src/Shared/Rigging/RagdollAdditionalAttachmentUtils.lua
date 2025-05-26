--[=[
	@class RagdollAdditionalAttachmentUtils
]=]

local require = require(script.Parent.loader).load(script)

local EnumUtils = require("EnumUtils")
local Maid = require("Maid")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local RxR15Utils = require("RxR15Utils")

local RagdollAdditionalAttachmentUtils = {}

local V3_ZERO = Vector3.zero
local V3_UP = Vector3.new(0, 1, 0)
local V3_DOWN = Vector3.new(0, -1, 0)
local V3_RIGHT = Vector3.new(1, 0, 0)
local V3_LEFT = Vector3.new(-1, 0, 0)

-- To model shoulder cone and twist limits correctly we really need the primary axis of the UpperArm
-- to be going down the limb. the waist and neck joints attachments actually have the same problem
-- of non-ideal axis orientation, but it's not as noticable there since the limits for natural
-- motion are tighter for those joints anyway.
local R15_ADDITIONAL_ATTACHMENTS = {
	{
		"UpperTorso",
		"RightShoulderRagdollAttachment",
		CFrame.fromMatrix(V3_ZERO, V3_RIGHT, V3_UP),
		"RightShoulderRigAttachment",
	},
	{
		"RightUpperArm",
		"RightShoulderRagdollAttachment",
		CFrame.fromMatrix(V3_ZERO, V3_DOWN, V3_RIGHT),
		"RightShoulderRigAttachment",
	},
	{
		"UpperTorso",
		"LeftShoulderRagdollAttachment",
		CFrame.fromMatrix(V3_ZERO, V3_LEFT, V3_UP),
		"LeftShoulderRigAttachment",
	},
	{
		"LeftUpperArm",
		"LeftShoulderRagdollAttachment",
		CFrame.fromMatrix(V3_ZERO, V3_DOWN, V3_LEFT),
		"LeftShoulderRigAttachment",
	},
}

local R6_ADDITIONAL_ATTACHMENTS = {
	{ "Head", "NeckAttachment", CFrame.new(0, -0.5, 0) },
	{ "Torso", "NeckAttachment", CFrame.new(0, 1, 0) },

	{ "Torso", "RightShoulderRagdollAttachment", CFrame.fromMatrix(Vector3.new(1, 0.5, 0), V3_RIGHT, V3_UP) },
	{ "Right Arm", "RightShoulderRagdollAttachment", CFrame.fromMatrix(Vector3.new(-0.5, 0.5, 0), V3_DOWN, V3_RIGHT) },

	{ "Torso", "LeftShoulderRagdollAttachment", CFrame.fromMatrix(Vector3.new(-1, 0.5, 0), V3_LEFT, V3_UP) },
	{ "Left Arm", "LeftShoulderRagdollAttachment", CFrame.fromMatrix(Vector3.new(0.5, 0.5, 0), V3_DOWN, V3_LEFT) },

	{ "Torso", "RightHipAttachment", CFrame.new(0.5, -1, 0) },
	{ "Right Leg", "RightHipAttachment", CFrame.new(0, 1, 0) },

	{ "Torso", "LeftHipAttachment", CFrame.new(-0.5, -1, 0) },
	{ "Left Leg", "LeftHipAttachment", CFrame.new(0, 1, 0) },
}

function RagdollAdditionalAttachmentUtils.getAdditionalAttachmentData(rigType)
	if rigType == Enum.HumanoidRigType.R15 then
		return R15_ADDITIONAL_ATTACHMENTS
	elseif rigType == Enum.HumanoidRigType.R6 then
		return R6_ADDITIONAL_ATTACHMENTS
	else
		error(string.format("[RagdollAdditionalAttachmentUtils] - Unknown rigType %q", tostring(rigType)))
	end
end

function RagdollAdditionalAttachmentUtils.ensureAdditionalAttachments(character, rigType)
	assert(typeof(character) == "Instance" and character:IsA("Model"), "Bad character")
	assert(EnumUtils.isOfType(Enum.HumanoidRigType, rigType), "Bad rigType")

	local topMaid = Maid.new()

	for _, data in RagdollAdditionalAttachmentUtils.getAdditionalAttachmentData(rigType) do
		local partName, attachmentName, cframe, baseAttachmentName = unpack(data)

		if baseAttachmentName then
			local observable = RxBrioUtils.flatCombineLatest({
				part = RxR15Utils.observeCharacterPartBrio(character, partName),
				baseAttachment = RxR15Utils.observeRigAttachmentBrio(character, partName, baseAttachmentName),
			})

			topMaid:GiveTask(observable:Subscribe(function(state)
				if state.part and state.baseAttachment then
					local maid = Maid.new()

					local attachment = Instance.new("Attachment")
					attachment.Name = attachmentName

					maid:GiveTask(
						RxInstanceUtils.observeProperty(state.baseAttachment, "CFrame"):Subscribe(function(baseCFrame)
							attachment.CFrame = baseCFrame * cframe
							attachment.Parent = state.part -- event ordering...
						end)
					)

					maid:GiveTask(attachment)

					topMaid[data] = maid
				else
					topMaid[data] = nil
				end
			end))
		else
			topMaid:GiveTask(RxR15Utils.observeCharacterPartBrio(character, partName):Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				local maid = brio:ToMaid()
				local part = brio:GetValue()

				local attachment = Instance.new("Attachment")
				attachment.Name = attachmentName
				attachment.CFrame = cframe
				attachment.Parent = part
				maid:GiveTask(attachment)
			end))
		end
	end

	return topMaid
end

return RagdollAdditionalAttachmentUtils
