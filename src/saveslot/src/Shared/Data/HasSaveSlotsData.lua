--!strict
--[=[
	@class HasSaveSlotsData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeData = require("AdorneeData")
local AdorneeDataEntry = require("AdorneeDataEntry")

return AdorneeData.new({
	ActiveSlotIndex = AdorneeDataEntry.optionalAttribute("number", "ActiveSlotIndex"),
	MaxSlotCount = math.huge,
})
