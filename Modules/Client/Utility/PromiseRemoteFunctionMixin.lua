--- Intended for classes that extend BaseObject only
-- @module PromiseRemoteFunctionMixin
-- @author Quenty

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local promiseChild = require("promiseChild")

local PromiseRemoteFunctionMixin = {}

function PromiseRemoteFunctionMixin:Add(class, remoteFunctionName)
	assert(remoteFunctionName)
	assert(not class.PromiseRemoteFunctionMixin)
	assert(not class._remoteFunctionName)

	class.PromiseRemoteFunction = self.PromiseRemoteFunction
	class._remoteFunctionName = remoteFunctionName
end

-- Initialize PromiseRemoteFunctionMixin
function PromiseRemoteFunctionMixin:PromiseRemoteFunction()
	if self._remoteEventPromise then
		return self._remoteEventPromise
	end

	self._remoteEventPromise = promiseChild(self._obj, self._remoteFunctionName)
	self._maid:GiveTask(self._remoteEventPromise)

	return self._remoteEventPromise
end


return PromiseRemoteFunctionMixin