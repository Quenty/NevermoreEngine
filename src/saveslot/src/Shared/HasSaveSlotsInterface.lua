--!strict
--[=[
	@class HasSaveSlotsInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("HasSaveSlots", {
	ActiveSlotId = TieDefinition.Types.PROPERTY,
	LastActiveSlotId = TieDefinition.Types.PROPERTY,
	MaxSlotCount = TieDefinition.Types.PROPERTY,

	PromiseHasSlot = TieDefinition.Types.METHOD,
	PromiseSelectSlot = TieDefinition.Types.METHOD,
	PromiseCreateSlot = TieDefinition.Types.METHOD,
	PromiseDeleteSlot = TieDefinition.Types.METHOD,
	PromiseSetSlotMetadata = TieDefinition.Types.METHOD,
	PromiseGetSlotMetadata = TieDefinition.Types.METHOD,
	PromiseSlotIdFromIndex = TieDefinition.Types.METHOD,
	PromiseLastActiveSlotId = TieDefinition.Types.METHOD,

	SlotChanged = TieDefinition.Types.SIGNAL,

	[TieDefinition.Realms.SERVER] = {
		ObserveActiveSlotStoreBrio = TieDefinition.Types.METHOD,
		PromiseActiveSlotStore = TieDefinition.Types.METHOD,
		PromiseSlotsLoaded = TieDefinition.Types.METHOD,
		PromiseDeselectSlot = TieDefinition.Types.METHOD,
		PromiseSelectLastSaveSlot = TieDefinition.Types.METHOD,
		PromiseSelectNewSaveSlot = TieDefinition.Types.METHOD,
		PromiseDeleteAllSlots = TieDefinition.Types.METHOD,
	},
})
