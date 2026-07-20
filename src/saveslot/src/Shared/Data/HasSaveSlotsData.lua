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
	MaxSlotCount = math.huge,
})
