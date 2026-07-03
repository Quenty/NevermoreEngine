--!strict
--[=[
	@class RogueModifierBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RoguePropertyModifierData = require("RoguePropertyModifierData")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")

local RogueModifierBase = setmetatable({}, BaseObject)
RogueModifierBase.ClassName = "RogueModifierBase"
RogueModifierBase.__index = RogueModifierBase

export type RogueModifierBase =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_tieRealmService: any,
			_data: any,
			Order: any,
			Source: any,
		},
		{} :: typeof({ __index = RogueModifierBase })
	))
	& BaseObject.BaseObject

function RogueModifierBase.new(obj: Instance, serviceBag: ServiceBag.ServiceBag): RogueModifierBase
	local self: RogueModifierBase = setmetatable(BaseObject.new(obj) :: any, RogueModifierBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._tieRealmService = self._serviceBag:GetService(TieRealmService)

	self._data = (RoguePropertyModifierData :: any):Create(self._obj)

	self.Order = self._data.Order
	self.Source = self._data.RoguePropertySourceLink

	return self
end

function RogueModifierBase.GetModifiedVersion(self: RogueModifierBase, _value: any): any
	error("Not implemented")
end

function RogueModifierBase.ObserveModifiedVersion(self: RogueModifierBase, _value: any): any
	error("Not implemented")
end

return RogueModifierBase
