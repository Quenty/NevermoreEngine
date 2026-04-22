--!strict
--[=[
	Left grip
	@class IKLeftGrip
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local IKGripBase = require("IKGripBase")
local ServiceBag = require("ServiceBag")

local IKLeftGrip = setmetatable({}, IKGripBase)
IKLeftGrip.ClassName = "IKLeftGrip"
IKLeftGrip.__index = IKLeftGrip

export type IKLeftGrip = typeof(setmetatable({} :: {}, {} :: typeof({ __index = IKLeftGrip }))) & IKGripBase.IKGripBase

function IKLeftGrip.new(objectValue: ObjectValue, serviceBag: ServiceBag.ServiceBag): IKLeftGrip
	local self: IKLeftGrip = setmetatable(IKGripBase.new(objectValue, serviceBag) :: any, IKLeftGrip)

	self:PromiseIKRig()
		:Then(function(ikRig)
			return self._maid:GivePromise(ikRig:PromiseLeftArm())
		end)
		:Then(function(leftArm)
			self._maid:GiveTask(leftArm:Grip(self:GetAttachment(), self:GetPriority()))
		end)

	return self
end

return Binder.new("IKLeftGrip", IKLeftGrip :: any) :: Binder.Binder<IKLeftGrip>
