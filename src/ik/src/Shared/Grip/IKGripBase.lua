--[=[
	Meant to be used with a binder
	@class IKGripBase
]=]

local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")
local promisePropertyValue = require("promisePropertyValue")

local IKGripBase = setmetatable({}, BaseObject)
IKGripBase.ClassName = "IKGripBase"
IKGripBase.__index = IKGripBase

function IKGripBase.new(objectValue: ObjectValue, serviceBag: ServiceBag.ServiceBag)
	local self = setmetatable(BaseObject.new(objectValue), IKGripBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._attachment = self._obj.Parent

	assert(self._obj:IsA("ObjectValue"), "Not an object value")
	assert(self._attachment:IsA("Attachment"), "Not parented to an attachment")

	return self
end

function IKGripBase:GetPriority(): number
	return 1
end

function IKGripBase:GetAttachment(): Attachment?
	return self._obj.Parent
end

function IKGripBase:PromiseIKRig()
	if self._ikRigPromise then
		return self._ikRigPromise
	end

	local ikService
	if RunService:IsServer() then
		ikService = self._serviceBag:GetService((require :: any)("IKService"))
	else
		ikService = self._serviceBag:GetService((require :: any)("IKServiceClient"))
	end

	local promise = promisePropertyValue(self._obj, "Value")
	self._maid:GiveTask(promise)

	self._ikRigPromise = promise:Then(function(humanoid)
		if not humanoid:IsA("Humanoid") then
			warn("[IKGripBase.PromiseIKRig] - Humanoid in link is not a humanoid")
			return Promise.rejected()
		end

		return self._maid:GivePromise(ikService:PromiseRig(humanoid))
	end)

	return self._ikRigPromise
end

return IKGripBase
