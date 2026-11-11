--!strict
--[=[
	@class HasSaveSlotsData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeData = require("AdorneeData")
local AdorneeDataEntry = require("AdorneeDataEntry")

return AdorneeData.new({
	ActiveSlotId = AdorneeDataEntry.optionalAttribute("string", "ActiveSlotId"),
	LastActiveSlotId = AdorneeDataEntry.optionalAttribute("string", "LastActiveSlotId"),
	-- The shared-store key of the active transferable ephemeral slot (nil otherwise), replicated so a
	-- client-initiated teleport can carry it (an ephemeral slot's own id is not resumable at the
	-- destination). See SaveSlotServiceClient's teleport provider.
	ActiveTransferableEphemeralKey = AdorneeDataEntry.optionalAttribute("string", "ActiveTransferableEphemeralKey"),
	MaxSlotCount = math.huge,
})
