--- Intended for classes that extend BaseObject only
-- @module PromiseRemoteEventMixin
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local promiseChild = require("promiseChild")

local PromiseRemoteEventMixin = {}

function PromiseRemoteEventMixin:Add(class, remoteEventName)
	assert(remoteEventName)
	assert(not class.PromiseRemoteEventMixin)
	assert(not class._remoteEventName)

	class.PromiseRemoteEvent = self.PromiseRemoteEvent
	class._remoteEventName = remoteEventName
end

-- Initialize PromiseRemoteEventMixin
function PromiseRemoteEventMixin:PromiseRemoteEvent()
	if self._remoteEventPromise then
		return self._remoteEventPromise
	end

	self._remoteEventPromise = promiseChild(self._obj, self._remoteEventName)
	self._maid:GiveTask(self._remoteEventPromise)

	return self._remoteEventPromise
end


return PromiseRemoteEventMixin