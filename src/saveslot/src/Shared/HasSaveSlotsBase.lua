--!strict
--[=[
	@class HasSaveSlotsBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local HasSaveSlotsData = require("HasSaveSlotsData")
local Promise = require("Promise")
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

--[=[
	Returns the save-slot id the player teleported in with, or nil. Realm hook: the server reads it
	from the join data, the client from the local player's teleport data (both via
	[TeleportDataService]). The base default returns nil so a realm that never sets one degrades to
	"no incoming slot".

	@return SaveSlotData.SlotId?
]=]
function HasSaveSlotsBase._getIncomingSlotId(_self: HasSaveSlotsBase): SaveSlotData.SlotId?
	return nil
end

--[=[
	Returns whether the player teleported in carrying a save-slot id that still exists for them.
	This is the existence-validated form of "internal teleport".

	@return Promise<boolean>
]=]
function HasSaveSlotsBase.PromiseHasSaveSlotFromTeleport(self: HasSaveSlotsBase): Promise.Promise<boolean>
	local slotId = self:_getIncomingSlotId()
	if type(slotId) ~= "string" then
		return (Promise :: any).resolved(false)
	end

	return (self :: any):PromiseHasSlot(slotId)
end

--[=[
	Selects the save slot the player teleported in with when it still exists, resolving to that slot
	id -- or nil when there was no incoming slot or it no longer exists. Reuses the realm's own
	`PromiseHasSlot`/`PromiseSelectSlot`, so it works identically on server and client.

	@return Promise<SaveSlotData.SlotId?>
]=]
function HasSaveSlotsBase.PromiseLoadSaveSlotFromTeleport(self: HasSaveSlotsBase): Promise.Promise<SaveSlotData.SlotId?>
	local slotId = self:_getIncomingSlotId()
	if type(slotId) ~= "string" then
		return (Promise :: any).resolved(nil)
	end

	return (self :: any):PromiseHasSlot(slotId):Then(function(hasSlot: boolean)
		if not hasSlot then
			return nil
		end

		return (self :: any):PromiseSelectSlot(slotId):Then(function()
			return slotId
		end)
	end)
end

return HasSaveSlotsBase
