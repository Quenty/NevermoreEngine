--!strict
--[=[
	@class RogueModifierBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RoguePropertyModifierData = require("RoguePropertyModifierData")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local ValueObject = require("ValueObject")

local RogueModifierBase = setmetatable({}, BaseObject)
RogueModifierBase.ClassName = "RogueModifierBase"
RogueModifierBase.__index = RogueModifierBase

export type RogueModifierBase =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_tieRealmService: TieRealmService.TieRealmService,
			-- _data is the AdorneeData "create" result for RoguePropertyModifierData,
			-- which is a nonstrict module exporting no type.
			_data: any,
			Order: ValueObject.ValueObject<number>,
			Source: ValueObject.ValueObject<Instance?>,
		},
		{} :: typeof({ __index = RogueModifierBase })
	))
	& BaseObject.BaseObject

function RogueModifierBase.new(obj: ValueBase, serviceBag: ServiceBag.ServiceBag): RogueModifierBase
	local self: RogueModifierBase = setmetatable(BaseObject.new(obj) :: any, RogueModifierBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	-- Cast: duplicate nested node_modules copies of TieRealmService produce a
	-- spurious "Expected 'TieRealmService', got 'TieRealmService'" cyclic error.
	self._tieRealmService = self._serviceBag:GetService(TieRealmService) :: any

	self._data = RoguePropertyModifierData:Create(self._obj)

	self.Order = self._data.Order
	self.Source = self._data.RoguePropertySourceLink

	return self
end

function RogueModifierBase.GetModifiedVersion(_self: RogueModifierBase, _value: any): any
	error("Not implemented")
end

function RogueModifierBase.ObserveModifiedVersion(_self: RogueModifierBase, _value: any): any
	error("Not implemented")
end

return RogueModifierBase
