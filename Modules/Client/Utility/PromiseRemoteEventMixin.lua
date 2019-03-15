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
	return self._maid:GivePromise(promiseChild(self._obj, self._remoteEventName))
end


return PromiseRemoteEventMixin