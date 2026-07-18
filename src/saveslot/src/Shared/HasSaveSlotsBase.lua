--!strict
--[=[
	@class HasSaveSlotsBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local HasSaveSlotsData = require("HasSaveSlotsData")
local SaveSlotData = require("SaveSlotData")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")
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

			ActiveSlotId: ValueObject.ValueObject<SaveSlotData.SlotId?>,
			LastActiveSlotId: ValueObject.ValueObject<SaveSlotData.SlotId?>,
			MaxSlotCount: ValueObject.ValueObject<number>,

			SlotChanged: Signal.Signal<SaveSlotData.SlotId>,
		},
		{} :: typeof({ __index = HasSaveSlotsBase })
	))
	& BaseObject.BaseObject

function HasSaveSlotsBase.new(player: Player, serviceBag: ServiceBag.ServiceBag): HasSaveSlotsBase
	local self: HasSaveSlotsBase = setmetatable(BaseObject.new(player) :: any, HasSaveSlotsBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._attributes = HasSaveSlotsData:Create(self._obj)

	self.ActiveSlotId = self._attributes.ActiveSlotId
	self.LastActiveSlotId = self._attributes.LastActiveSlotId
	self.MaxSlotCount = self._attributes.MaxSlotCount

	self.SlotChanged = self.ActiveSlotId.Changed

	return self
end

return HasSaveSlotsBase
