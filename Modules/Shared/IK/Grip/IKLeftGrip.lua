--- Left grip
-- @classmod IKLeftGrip

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local IKGripBase = require("IKGripBase")

local IKLeftGrip = setmetatable({}, IKGripBase)
IKLeftGrip.ClassName = "IKLeftGrip"
IKLeftGrip.__index = IKLeftGrip

function IKLeftGrip.new(objectValue)
	local self = setmetatable(IKGripBase.new(objectValue), IKLeftGrip)

	self:PromiseIKRig()
		:Then(function(ikRig)
			return self._maid:GivePromise(ikRig:PromiseLeftArm())
		end)
		:Then(function(leftArm)
			self._maid:GiveTask(leftArm:Grip(self:GetAttachment(), self:GetPriority()))
		end)

	return self
end

return IKLeftGrip