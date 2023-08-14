--[=[
	@class RogueAdditive
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RxValueBaseUtils = require("RxValueBaseUtils")
local Binder = require("Binder")

local RogueAdditive = setmetatable({}, BaseObject)
RogueAdditive.ClassName = "RogueAdditive"
RogueAdditive.__index = RogueAdditive

function RogueAdditive.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), RogueAdditive)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

function RogueAdditive:GetObject()
	return self._obj
end

function RogueAdditive:ObserveAdditive()
	return RxValueBaseUtils.observeValue(self._obj)
end

function RogueAdditive:GetAdditive()
	return self._obj.Value
end

return Binder.new("RogueAdditive", RogueAdditive)