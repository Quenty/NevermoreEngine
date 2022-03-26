--[=[
	@class Door
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local OpenableInterface = require("OpenableInterface")
local Promise = require("Promise")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local Door = setmetatable({}, BaseObject)
Door.ClassName = "Door"
Door.__index = Door

function Door.new(obj)
	local self = setmetatable(BaseObject.new(obj), Door)

	self.Opening = Signal.new()
	self._maid:GiveTask(self.Opening)

	self.Closing = Signal.new()
	self._maid:GiveTask(self.Closing)

	self.IsOpen = Instance.new("BoolValue")
	self.IsOpen.Value = false
	self._maid:GiveTask(self.IsOpen)

	self.LastPromise = ValueObject.new()
	self._maid:GiveTask(self.LastPromise)

	self._maid:GiveTask(OpenableInterface:Implement(self._obj, self))

	return self
end

function Door:PromiseOpen()
	self.Opening:Fire()
	self.IsOpen.Value = true

	local promise = Promise.new(function(resolve)
		task.delay(1, resolve)
	end)

	self.LastPromise.Value = promise

	return promise
end

function Door:PromiseClose()
	self.Closing:Fire()
	self.IsOpen.Value = false

	local promise = Promise.new(function(resolve)
		task.delay(1, resolve)
	end)

	self.LastPromise.Value = promise

	return promise
end

return Door