--[=[
	Utility methods for grip attachments
	@class IKGripUtils
]=]

local IKGripUtils = {}

--[=[
	Parent to the attachment we want the humanoid to grip.

	```lua
	-- Get the binder
	local leftGripAttachmentBinder = serviceBag:GetService(require("IKLeftGrip"))

	-- Setup sample grip
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.Name = "GripTarget"

	-- This will make the NPC try to grip this attachment
	local objectValue = IKGripUtils.create(leftGripAttachmentBinder, workspace.NPC.Humanoid)
	objectValue.Parent = attachment
	```

	@param binder Binder
	@param humanoid Humanoid
	@return ObjectValue
]=]
function IKGripUtils.create(binder, humanoid)
	assert(binder, "Bad binder")
	assert(typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid"), "Bad humanoid")

	local objectValue = Instance.new("ObjectValue")
	objectValue.Name = binder:GetTag()
	objectValue.Value = humanoid

	binder:Bind(objectValue)

	return objectValue
end

return IKGripUtils
