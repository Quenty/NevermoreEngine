--!strict
--[=[
	@class HasSaveSlotsBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local HasSaveSlotsData = require("HasSaveSlotsData")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local HasSaveSlotsBase = setmetatable({}, BaseObject)
HasSaveSlotsBase.ClassName = "HasSaveSlotsBase"
HasSaveSlotsBase.__index = HasSaveSlotsBase

export type HasSaveSlotsBase =
	typeof(setmetatable(
		{} :: {
			_obj: Player,
			_serviceBag: ServiceBag.ServiceBag,
			_attributes: any,

			ActiveSlotIndex: ValueObject.ValueObject<number?>,
			MaxSlotCount: ValueObject.ValueObject<number>,
		},
		{} :: typeof({ __index = HasSaveSlotsBase })
	))
	& BaseObject.BaseObject

function HasSaveSlotsBase.new(player: Player, serviceBag: ServiceBag.ServiceBag): HasSaveSlotsBase
	local self: HasSaveSlotsBase = setmetatable(BaseObject.new(player) :: any, HasSaveSlotsBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._attributes = HasSaveSlotsData:Create(self._obj)

	self.ActiveSlotIndex = self._attributes.ActiveSlotIndex
	self.MaxSlotCount = self._attributes.MaxSlotCount

	return self
end

return HasSaveSlotsBase
