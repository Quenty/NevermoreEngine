--- Right grip attachment
-- @classmod IKRightGripAttachment

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local GripAttachment = require("GripAttachment")

local IKRightGripAttachment = setmetatable({}, GripAttachment)
IKRightGripAttachment.ClassName = "IKRightGripAttachment"
IKRightGripAttachment.__index = IKRightGripAttachment

function IKRightGripAttachment.new(obj)
	local self = setmetatable(GripAttachment.new(obj), IKRightGripAttachment)

	local rig = self:GetIKRig()
	if rig then
		self._maid:GivePromise(self._ikRig:PromiseRightArm()):Then(function(rightArm)
			self._maid:GiveTask(rightArm:Grip(self._obj, self:GetPriority()))
		end)
	else
		warn("[IKRightGripAttachment.new] - Failed to find rig")
	end

	return self
end

return IKRightGripAttachment