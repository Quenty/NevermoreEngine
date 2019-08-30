--- Left grip attachment
-- @classmod IKLeftGripAttachment

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local GripAttachment = require("GripAttachment")

local IKLeftGripAttachment = setmetatable({}, GripAttachment)
IKLeftGripAttachment.ClassName = "IKLeftGripAttachment"
IKLeftGripAttachment.__index = IKLeftGripAttachment

function IKLeftGripAttachment.new(obj)
	local self = setmetatable(GripAttachment.new(obj), IKLeftGripAttachment)

	local rig = self:GetIKRig()
	if rig then
		self._maid:GivePromise(self._ikRig:PromiseLeftArm()):Then(function(leftArm)
			self._maid:GiveTask(leftArm:Grip(self._obj, self:GetPriority()))
		end)
	else
		warn("[IKLeftGripAttachment.new] - Failed to find rig")
	end

	return self
end

return IKLeftGripAttachment