--- Right grip attachment
-- @classmod IKRightGripAttachment

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local GripAttachment = require("GripAttachment")

local IKRightGripAttachment = setmetatable({}, GripAttachment)
IKRightGripAttachment.ClassName = "IKRightGripAttachment"
IKRightGripAttachment.__index = IKRightGripAttachment

function IKRightGripAttachment.new(obj)
	local self = setmetatable(GripAttachment.new(obj), IKRightGripAttachment)

	self:PromiseIKRig()
		:Then(function(ikRig)
			return self._maid:GivePromise(ikRig:PromiseRightArm())
		end):Then(function(rightArm)
			self._maid:GiveTask(rightArm:Grip(self._obj, self:GetPriority()))
		end)

	return self
end

return IKRightGripAttachment