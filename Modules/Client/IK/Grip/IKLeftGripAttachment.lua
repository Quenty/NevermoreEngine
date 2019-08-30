--- Left grip attachment
-- @classmod IKLeftGripAttachment

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local GripAttachment = require("GripAttachment")

local IKLeftGripAttachment = setmetatable({}, GripAttachment)
IKLeftGripAttachment.ClassName = "IKLeftGripAttachment"
IKLeftGripAttachment.__index = IKLeftGripAttachment

function IKLeftGripAttachment.new(obj)
	local self = setmetatable(GripAttachment.new(obj), IKLeftGripAttachment)

	self:PromiseIKRig()
		:Then(function(ikRig)
			return self._maid:GivePromise(ikRig:PromiseLeftArm())
		end):Then(function(leftArm)
			self._maid:GiveTask(leftArm:Grip(self._obj, self:GetPriority()))
		end)

	return self
end

return IKLeftGripAttachment