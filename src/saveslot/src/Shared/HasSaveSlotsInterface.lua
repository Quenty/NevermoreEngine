--!strict
--[=[
	@class HasSaveSlotsInterface
]=]

local require = require(script.Parent.loader).load(script)

local TieDefinition = require("TieDefinition")

return TieDefinition.new("HasSaveSlots", {
	ActiveSlotIndex = TieDefinition.Types.PROPERTY,
	MaxSlotCount = TieDefinition.Types.PROPERTY,

	PromiseHasSlot = TieDefinition.Types.METHOD,
	PromiseSelectSlot = TieDefinition.Types.METHOD,
	PromiseCreateSlot = TieDefinition.Types.METHOD,
	PromiseDeleteSlot = TieDefinition.Types.METHOD,
	PromiseSetSlotMetadata = TieDefinition.Types.METHOD,
	PromiseGetSlotMetadata = TieDefinition.Types.METHOD,
	PromiseLastActiveSlotIndex = TieDefinition.Types.METHOD,
	PromiseRefreshActiveSlotSummary = TieDefinition.Types.METHOD,
})
