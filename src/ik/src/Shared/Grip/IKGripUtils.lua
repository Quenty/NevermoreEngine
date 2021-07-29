--- Utility methods for grip attachments
-- @module IKGripUtils

local IKGripUtils = {}

-- Parent to the attachment we want the humanoid to grip
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