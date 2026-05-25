--!strict
--[=[
	@class SaveSlotData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeData = require("AdorneeData")
local AdorneeDataEntry = require("AdorneeDataEntry")
local PropertyValue = require("PropertyValue")

export type SaveSlotMetadata = {
	SlotId: string,
	SlotIndex: number,
	SlotName: string?,
	CreatedTime: number?,
	LastPlayedTime: number?,
	Summary: string?,
}

return AdorneeData.new({
	SlotId = AdorneeDataEntry.new("string", function(folder: Folder)
		return PropertyValue.new(folder, "Name")
	end),
	SlotIndex = 0,
	SlotName = AdorneeDataEntry.optionalAttribute("string", "SlotName"),
	CreatedTime = AdorneeDataEntry.optionalAttribute("number", "CreatedTime"),
	LastPlayedTime = AdorneeDataEntry.optionalAttribute("number", "LastPlayedTime"),
	Summary = AdorneeDataEntry.optionalAttribute("string", "Summary"),
})
