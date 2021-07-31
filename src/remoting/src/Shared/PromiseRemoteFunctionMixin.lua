--- Intended for classes that extend BaseObject only
-- @module PromiseRemoteFunctionMixin

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local promiseChild = require("promiseChild")

local PromiseRemoteFunctionMixin = {}

function PromiseRemoteFunctionMixin:Add(class, remoteFunctionName)
	assert(remoteFunctionName, "Bad remoteFunctionName")
	assert(not class.PromiseRemoteFunctionMixin, "Class already has PromiseRemoteFunctionMixin defined")
	assert(not class._remoteFunctionName, "Class already has _remoteFunctionName defined")

	class.PromiseRemoteFunction = self.PromiseRemoteFunction
	class._remoteFunctionName = remoteFunctionName
end

-- Initialize PromiseRemoteFunctionMixin
function PromiseRemoteFunctionMixin:PromiseRemoteFunction()
	return self._maid:GivePromise(promiseChild(self._obj, self._remoteFunctionName))
end


return PromiseRemoteFunctionMixin