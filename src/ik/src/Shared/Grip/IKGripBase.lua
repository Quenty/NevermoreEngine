--- Meant to be used with a binder
-- @classmod IKGripBase

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local RunService = game:GetService("RunService")

local BaseObject = require("BaseObject")
local promisePropertyValue = require("promisePropertyValue")
local Promise = require("Promise")

local IKGripBase = setmetatable({}, BaseObject)
IKGripBase.ClassName = "IKGripBase"
IKGripBase.__index = IKGripBase

function IKGripBase.new(objectValue)
	local self = setmetatable(BaseObject.new(objectValue), IKGripBase)

	self._attachment = self._obj.Parent

	assert(self._obj:IsA("ObjectValue"), "Not an object value")
	assert(self._attachment:IsA("Attachment"), "Not parented to an attachment")

	return self
end

function IKGripBase:GetPriority()
	return 1
end

function IKGripBase:GetAttachment()
	return self._obj.Parent
end

function IKGripBase:PromiseIKRig()
	if self._ikRigPromise then
		return self._ikRigPromise
	end

	local ikService
	if RunService:IsServer() then
		ikService = require("IKService")
	else
		ikService = require("IKServiceClient")
	end

	local promise = promisePropertyValue(self._obj, "Value")
	self._maid:GiveTask(promise)

	self._ikRigPromise = promise
		:Then(function(humanoid)
			if not humanoid:IsA("Humanoid") then
				warn("[IKGripBase.PromiseIKRig] - Humanoid in link is not a humanoid")
				return Promise.rejected()
			end

			local rig = ikService:GetRig(humanoid)
			if not rig then
				warn("[IKGripBase.PromiseIKRig] - No rig found for humanoid!")
				return Promise.rejected()
			end

			return rig
		end)

	return self._ikRigPromise
end

return IKGripBase