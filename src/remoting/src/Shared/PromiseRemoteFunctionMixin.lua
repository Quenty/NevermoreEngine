--!strict
--[=[
	Intended for classes that extend BaseObject only
	@class PromiseRemoteFunctionMixin
]=]

local require = require(script.Parent.loader).load(script)

local promiseChild = require("promiseChild")

local PromiseRemoteFunctionMixin = {}

--[=[
	Adds the remote function mixin to a class

	```lua
	local BaseObject = require("BaseObject")

	local Bird = setmetatable({}, BaseObject)
	Bird.ClassName = "Bird"
	Bird.__index = Bird

	require("PromiseRemoteFunctionMixin"):Add(Bird, "BirdRemoteFunction")

	function Bird.new(inst)
		local self = setmetatable(BaseObject.new(inst), Bird)

		self:PromiseRemoteFunction():Then(function(remoteFunction)
			task.spawn(function()
				remoteFunction:InvokeServer() -- or whatever
			end)
		end)

		return self
	end
	```

	@param class { _maid: Maid }
	@param remoteFunctionName string
]=]
function PromiseRemoteFunctionMixin:Add(class, remoteFunctionName)
	assert(type(class) == "table", "Bad class")
	assert(type(remoteFunctionName) == "string", "Bad remoteFunctionName")
	assert(not class.PromiseRemoteFunctionMixin, "Class already has PromiseRemoteFunctionMixin defined")
	assert(not class._remoteFunctionName, "Class already has _remoteFunctionName defined")

	class.PromiseRemoteFunction = self.PromiseRemoteFunction
	class._remoteFunctionName = remoteFunctionName
end

--[=[
	Returns a promise that returns a remote function
	@return Promise<RemoteFunction>
]=]
function PromiseRemoteFunctionMixin:PromiseRemoteFunction()
	return self._maid:GivePromise(promiseChild(self._obj, self._remoteFunctionName))
end

return PromiseRemoteFunctionMixin
