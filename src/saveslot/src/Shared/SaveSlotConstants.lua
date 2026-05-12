--!strict
--[=[
	@class SaveSlotConstants
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	METADATA_CONTAINER_NAME = "SaveSlots",
	DEFAULT_SLOT_INDEX = 1,
})
