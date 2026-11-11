--!strict
--[=[
	@class SaveSlotConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	SYSTEM_STORE_KEY = "SaveSlots",
	SLOT_STORE_KEY = "slots",
	METADATA_STORE_KEY = "slotMetadata",
	METADATA_CONTAINER_NAME = "SaveSlots",
	TELEPORT_DATA_SLOT_KEY = "IncomingSaveSlotId",
	-- Carries the shared-store key of a transferable ephemeral slot across a teleport (trusted band).
	TELEPORT_DATA_EPHEMERAL_KEY = "IncomingEphemeralSaveSlotKey",
	DEFAULT_SLOT_INDEX = 1,
	-- An ephemeral slot carries no meaningful index -- a real slot's index positions it in the save list and
	-- routes its store, neither of which applies to a throwaway slot. The authoritative "is ephemeral"
	-- discriminator is the slot's own IsEphemeral property (see HasSaveSlots._isEphemeral), and every
	-- index-accounting path skips ephemeral slots, so this value never routes anything and any number of
	-- ephemeral slots can coexist. 0 is used because a real index is always >= 1 (DEFAULT_SLOT_INDEX is 1,
	-- PromiseCreateSlot rejects < 1), which also makes it a free address for tooling that has to name the
	-- active ephemeral slot (see SaveSlotCmdrUtils).
	EPHEMERAL_SLOT_INDEX = 0,
})
