--!strict
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

export type IKGripBase =
	typeof(setmetatable(
		{} :: {
			_obj: Instance,
			_serviceBag: ServiceBag.ServiceBag,
			_attachment: Attachment,
			_ikRigPromise: Promise.Promise<any>,
		},
		{} :: typeof({ __index = IKGripBase })
	))
	& BaseObject.BaseObject

function IKGripBase.new(objectValue: ObjectValue, serviceBag: ServiceBag.ServiceBag): IKGripBase
	local self: IKGripBase = setmetatable(BaseObject.new(objectValue) :: any, IKGripBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._attachment = self._obj.Parent :: any

	assert(self._obj:IsA("ObjectValue"), "Not an object value")
	assert(self._attachment:IsA("Attachment"), "Not parented to an attachment")

	return self
end

function IKGripBase.GetPriority(_self: IKGripBase): number
	return 1
end

function IKGripBase.GetAttachment(self: IKGripBase): Attachment?
	return self._attachment
end

function IKGripBase.PromiseIKRig(self: IKGripBase): Promise.Promise<any>
	if self._ikRigPromise then
		return self._ikRigPromise
	end

	local ikService
	if RunService:IsServer() then
		ikService = self._serviceBag:GetService((require :: any)("IKService"))
	else
		ikService = self._serviceBag:GetService((require :: any)("IKServiceClient"))
	end

	self._ikRigPromise = self._maid:Add(promisePropertyValue(self._obj, "Value")):Then(function(humanoid)
		if not humanoid:IsA("Humanoid") then
			warn("[IKGripBase.PromiseIKRig] - Humanoid in link is not a humanoid")
			return Promise.rejected()
		end

		return self._maid:GivePromise(ikService:PromiseRig(humanoid))
	end)

	return self._ikRigPromise :: any
end

return IKGripBase
