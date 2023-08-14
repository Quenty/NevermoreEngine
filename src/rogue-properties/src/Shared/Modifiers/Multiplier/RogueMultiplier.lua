--[=[
	@class RogueMultiplier
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RxValueBaseUtils = require("RxValueBaseUtils")
local Binder = require("Binder")

local RogueMultiplier = setmetatable({}, BaseObject)
RogueMultiplier.ClassName = "RogueMultiplier"
RogueMultiplier.__index = RogueMultiplier

function RogueMultiplier.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), RogueMultiplier)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

function RogueMultiplier:ObserveMultiplier()
	return RxValueBaseUtils.observeValue(self._obj)
end

function RogueMultiplier:GetMultiplier()
	return self._obj.Value
end

function RogueMultiplier:GetObject()
	return self._obj
end

return Binder.new("RogueMultiplier", RogueMultiplier)