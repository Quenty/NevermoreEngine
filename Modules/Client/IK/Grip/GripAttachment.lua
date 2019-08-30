--- Meant to be used with a binder
-- @classmod GripAttachment

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local BaseObject = require("BaseObject")
local IKServiceClient = require("IKServiceClient")
local promiseChild = require("promiseChild")
local promisePropertyValue = require("promisePropertyValue")
local GripAttachmentConstants = require("GripAttachmentConstants")
local Promise = require("Promise")

local GripAttachment = setmetatable({}, BaseObject)
GripAttachment.ClassName = "GripAttachment"
GripAttachment.__index = GripAttachment

function GripAttachment.new(obj)
	local self = setmetatable(BaseObject.new(obj), GripAttachment)

	assert(self._obj:IsA("Attachment"))

	return self
end

function GripAttachment:GetPriority()
	return 1
end

function GripAttachment:PromiseIKRig()
	if self._ikRigPromise then
		return self._ikRigPromise
	end

	local promiseHumanoidLink = self._maid:GivePromise(promiseChild(self._obj, GripAttachmentConstants.HUMANOID_LINK_NAME))

	self._ikRigPromise = promiseHumanoidLink
		:Then(function(humanoidLink)
			local promise = promisePropertyValue(humanoidLink, "Value")
			self._maid:GiveTask(promise)
			return promise
		end):Then(function(humanoid)
			if not humanoid:IsA("Humanoid") then
				return Promise.rejected("Humanoid in link is not a humanoid")
			end

			local rig = IKServiceClient:GetRig(humanoid)
			if not rig then
				return Promise.rejected("No rig found for humanoid!")
			end

			return rig
		end)

	return self._ikRigPromise
end

return GripAttachment