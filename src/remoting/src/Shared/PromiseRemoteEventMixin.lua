--!strict
--[=[
	Intended for classes that extend BaseObject only
	@class PromiseRemoteEventMixin
]=]

local require = require(script.Parent.loader).load(script)

local promiseChild = require("promiseChild")

local PromiseRemoteEventMixin = {}

--[=[
	Adds the remote function mixin to a class

	```lua
	local BaseObject = require("BaseObject")

	local Bird = setmetatable({}, BaseObject)
	Bird.ClassName = "Bird"
	Bird.__index = Bird

	require("PromiseRemoteEventMixin"):Add(Bird, "BirdRemoteEvent")

	function Bird.new(inst)
		local self = setmetatable(BaseObject.new(inst), Bird)

		self:PromiseRemoteEvent():Then(function(remoteEvent)
			self._maid:GiveTask(remoteEvent.OnClientEvent:Connect(function(...)
				self:_handleRemoteEvent(...)
			end)
		end)

		return self
	end
	```

	@param class { _maid: Maid }
	@param remoteEventName string
]=]
function PromiseRemoteEventMixin:Add(class, remoteEventName)
	assert(type(class) == "table", "Bad class")
	assert(type(remoteEventName) == "string", "Bad remoteEventName")
	assert(not class.PromiseRemoteEventMixin, "Class already has PromiseRemoteEventMixin defined")
	assert(not class._remoteEventName, "Class already has _remoteEventName defined")

	class.PromiseRemoteEvent = self.PromiseRemoteEvent
	class._remoteEventName = remoteEventName
end

--[=[
	Returns a promise that returns a remote event
	@return Promise<RemoteEvent>
]=]
function PromiseRemoteEventMixin:PromiseRemoteEvent()
	return self._maid:GivePromise(promiseChild(self._obj, self._remoteEventName))
end

return PromiseRemoteEventMixin
