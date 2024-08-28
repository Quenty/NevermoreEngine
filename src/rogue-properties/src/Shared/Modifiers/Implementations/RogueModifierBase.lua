--[=[
	@class RogueModifierBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local TieRealmService = require("TieRealmService")
local RoguePropertyModifierData = require("RoguePropertyModifierData")

local RogueModifierBase = setmetatable({}, BaseObject)
RogueModifierBase.ClassName = "RogueModifierBase"
RogueModifierBase.__index = RogueModifierBase

function RogueModifierBase.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), RogueModifierBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._tieRealmService = self._serviceBag:GetService(TieRealmService)

	self._data = RoguePropertyModifierData:Create(self._obj)

	self.Order = self._data.Order
	self.Source = self._data.RoguePropertySourceLink

	return self
end

function RogueModifierBase:GetModifiedVersion(_value)
	error("Not implemented")
end

function RogueModifierBase:ObserveModifiedVersion(_value)
	error("Not implemented")
end

return RogueModifierBase