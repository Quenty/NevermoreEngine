--[[
	@class Door
]]

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

	self.Opening = self._maid:Add(Signal.new())
	self.Closing = self._maid:Add(Signal.new())

	self.IsOpen = self._maid:Add(Instance.new("BoolValue"))
	self.IsOpen.Value = false

	self.LastPromise = self._maid:Add(ValueObject.new())

	self._maid:GiveTask(OpenableInterface.Server:Implement(self._obj, self))

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
