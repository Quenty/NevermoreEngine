--[=[
	@class RogueSetter
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RxValueBaseUtils = require("RxValueBaseUtils")
local Binder = require("Binder")

local RogueSetter = setmetatable({}, BaseObject)
RogueSetter.ClassName = "RogueSetter"
RogueSetter.__index = RogueSetter

function RogueSetter.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), RogueSetter)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

function RogueSetter:ObserveValue()
	return RxValueBaseUtils.observeValue(self._obj)
end

function RogueSetter:GetValue()
	return self._obj.Value
end

function RogueSetter:GetObject()
	return self._obj
end

return Binder.new("RogueSetter", RogueSetter)