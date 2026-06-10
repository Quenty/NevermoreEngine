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
	DEFAULT_SLOT_INDEX = 1,
})
