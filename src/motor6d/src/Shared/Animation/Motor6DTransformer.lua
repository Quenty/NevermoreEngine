--[=[
	@class Motor6DTransformer
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Signal = require("Signal")

local Motor6DTransformer = setmetatable({}, BaseObject)
Motor6DTransformer.ClassName = "Motor6DTransformer"
Motor6DTransformer.__index = Motor6DTransformer

function Motor6DTransformer.new()
	local self = setmetatable(BaseObject.new(), Motor6DTransformer)

	self.Finished = Signal.new()
	self._maid:GiveTask(function()
		self.Finished:Fire()
		self.Finished:Destroy()
	end)

	return self
end

function Motor6DTransformer:Transform()
	error("Not implemented")
end

function Motor6DTransformer:FireFinished()
	self.Finished:Fire()
end

return Motor6DTransformer
