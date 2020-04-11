--- Right grip
-- @classmod IKRightGrip

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local IKGripBase = require("IKGripBase")

local IKRightGrip = setmetatable({}, IKGripBase)
IKRightGrip.ClassName = "IKRightGrip"
IKRightGrip.__index = IKRightGrip

function IKRightGrip.new(objectValue)
	local self = setmetatable(IKGripBase.new(objectValue), IKRightGrip)

	self:PromiseIKRig()
		:Then(function(ikRig)
			return self._maid:GivePromise(ikRig:PromiseRightArm())
		end)
		:Then(function(rightArm)
			self._maid:GiveTask(rightArm:Grip(self:GetAttachment(), self:GetPriority()))
		end)

	return self
end

return IKRightGrip