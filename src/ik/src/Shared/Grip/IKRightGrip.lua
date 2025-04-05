--[=[
	Right grip
	@class IKRightGrip
]=]

local require = require(script.Parent.loader).load(script)

local IKGripBase = require("IKGripBase")
local Binder = require("Binder")

local IKRightGrip = setmetatable({}, IKGripBase)
IKRightGrip.ClassName = "IKRightGrip"
IKRightGrip.__index = IKRightGrip

function IKRightGrip.new(objectValue: ObjectValue, serviceBag)
	local self = setmetatable(IKGripBase.new(objectValue, serviceBag), IKRightGrip)

	self:PromiseIKRig()
		:Then(function(ikRig)
			return self._maid:GivePromise(ikRig:PromiseRightArm())
		end)
		:Then(function(rightArm)
			self._maid:GiveTask(rightArm:Grip(self:GetAttachment(), self:GetPriority()))
		end)

	return self
end

return Binder.new("IKRightGrip", IKRightGrip)