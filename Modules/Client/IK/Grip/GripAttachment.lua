--- Meant to be used with a binder
-- @classmod GripAttachment

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local IKServiceClient = require("IKServiceClient")

local GripAttachment = setmetatable({}, BaseObject)
GripAttachment.ClassName = "GripAttachment"
GripAttachment.__index = GripAttachment

function GripAttachment.new(obj)
	local self = setmetatable(BaseObject.new(obj), GripAttachment)

	assert(self._obj:IsA("Attachment"))

	return self
end

function GripAttachment:GetPriority()
	return 1
end

function GripAttachment:GetIKRig()
	local humanoid = self._obj:FindFirstAncestorOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	return IKServiceClient:GetRig(humanoid)
end

return GripAttachment