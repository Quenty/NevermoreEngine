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

	-- Answered from the teleport data the player arrived with (see HasSaveSlotsBase); both realms
	-- resolve the incoming slot id from their own [TeleportDataService].
	PromiseHasSaveSlotFromTeleport = TieDefinition.Types.METHOD,
	PromiseLoadSaveSlotFromTeleport = TieDefinition.Types.METHOD,

	SlotChanged = TieDefinition.Types.SIGNAL,

	[TieDefinition.Realms.SERVER] = {
		ObserveActiveSlotStoreBrio = TieDefinition.Types.METHOD,
		PromiseActiveSlotStore = TieDefinition.Types.METHOD,
		PromiseSlotsLoaded = TieDefinition.Types.METHOD,
		PromiseDeselectSlot = TieDefinition.Types.METHOD,
		PromiseSelectLastSaveSlot = TieDefinition.Types.METHOD,
		PromiseSelectNewSaveSlot = TieDefinition.Types.METHOD,
		PromiseSelectEphemeralSlot = TieDefinition.Types.METHOD,
		PromiseDeleteAllSlots = TieDefinition.Types.METHOD,

		-- Export/import operate on the server's datastore-backed slots and are refused on the main
		-- slot (see SaveSlotExportUtils); server realm only.
		PromiseExportSlot = TieDefinition.Types.METHOD,
		PromiseImportSlot = TieDefinition.Types.METHOD,
	},
})
