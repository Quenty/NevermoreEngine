--- Utility methods for grip attachments
-- @module GripAttachmentUtils

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local GripAttachmentConstants = require("GripAttachmentConstants")

local GripAttachmentUtils = {}

function GripAttachmentUtils.create(binder, part, worldPosition, humanoid)
	assert(binder)
	assert(typeof(part) == "Instance")
	assert(typeof(worldPosition) == "Vector3")
	assert(typeof(humanoid) == "Instance")

	local gripAttachment = Instance.new("Attachment")
	gripAttachment.Name = binder:GetTag()
	gripAttachment.Position = part.CFrame:pointToObjectSpace(worldPosition)

	local humanoidLink = Instance.new("ObjectValue")
	humanoidLink.Name = GripAttachmentConstants.HUMANOID_LINK_NAME
	humanoidLink.Value = humanoid
	humanoidLink.Parent = gripAttachment

	gripAttachment.Parent = part

	binder:Bind(gripAttachment)

	return gripAttachment
end

return GripAttachmentUtils