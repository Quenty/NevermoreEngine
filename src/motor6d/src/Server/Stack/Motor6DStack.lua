--[=[
	@class Motor6DStack
]=]

local require = require(script.Parent.loader).load(script)

local Motor6DStackBase = require("Motor6DStackBase")

local Motor6DStack = setmetatable({}, Motor6DStackBase)
Motor6DStack.ClassName = "Motor6DStack"
Motor6DStack.__index = Motor6DStack

function Motor6DStack.new(obj, serviceBag)
	local self = setmetatable(Motor6DStackBase.new(obj), Motor6DStack)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

return Motor6DStack