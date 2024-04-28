--[=[
	Left grip
	@class IKLeftGrip
]=]

local require = require(script.Parent.loader).load(script)

local IKGripBase = require("IKGripBase")
local Binder = require("Binder")

local IKLeftGrip = setmetatable({}, IKGripBase)
IKLeftGrip.ClassName = "IKLeftGrip"
IKLeftGrip.__index = IKLeftGrip

function IKLeftGrip.new(objectValue, serviceBag)
	local self = setmetatable(IKGripBase.new(objectValue, serviceBag), IKLeftGrip)

	self:PromiseIKRig()
		:Then(function(ikRig)
			return self._maid:GivePromise(ikRig:PromiseLeftArm())
		end)
		:Then(function(leftArm)
			self._maid:GiveTask(leftArm:Grip(self:GetAttachment(), self:GetPriority()))
		end)

	return self
end

return Binder.new("IKLeftGrip", IKLeftGrip)