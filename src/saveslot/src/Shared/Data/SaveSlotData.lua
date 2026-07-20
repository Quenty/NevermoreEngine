--!strict
--[=[
	@class SaveSlotData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeData = require("AdorneeData")
local AdorneeDataEntry = require("AdorneeDataEntry")
local PropertyValue = require("PropertyValue")

export type SlotId = string

export type SaveSlotMetadata = {
	SlotId: SlotId,
	SlotIndex: number,
	SlotName: string?,
	CreatedTime: number?,
	LastPlayedTime: number?,
	Summary: string?,
	-- Accrued automatically by HasSaveSlots while the slot is the active slot; see _setupPlaytimeTracking.
	TimePlayed: number?, -- total seconds the slot has been actively played, across every session
	PlayCount: number?, -- number of sessions (incremented each time the slot is selected)
	LastSessionLength: number?, -- seconds of the current/most-recent session
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
	TimePlayed = AdorneeDataEntry.optionalAttribute("number", "TimePlayed"),
	PlayCount = AdorneeDataEntry.optionalAttribute("number", "PlayCount"),
	LastSessionLength = AdorneeDataEntry.optionalAttribute("number", "LastSessionLength"),
})
