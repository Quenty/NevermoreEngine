--!strict
--[=[
	@class SaveSlotData
]=]

local require = require(script.Parent.loader).load(script)

local AdorneeData = require("AdorneeData")
local AdorneeDataEntry = require("AdorneeDataEntry")
local JSONAttributeValue = require("JSONAttributeValue")
local PropertyValue = require("PropertyValue")

export type SlotId = string

-- A slot's Summary is the structured preview shown in a slot-selection UI, keyed by summary-provider
-- name (see HasSaveSlots.RegisterSummaryProvider). It is JSON-encoded into a single attribute, so the
-- values must be JSON-serializable.
export type SaveSlotSummary = { [string]: any }

export type SaveSlotMetadata = {
	SlotId: SlotId,
	SlotIndex: number,
	SlotName: string?,
	CreatedTime: number?,
	LastPlayedTime: number?,
	Summary: SaveSlotSummary?,
	-- Accrued automatically by HasSaveSlots while the slot is the active slot; see _setupPlaytimeTracking.
	TimePlayed: number?, -- total seconds the slot has been actively played, across every session
	PlayCount: number?, -- number of sessions (incremented each time the slot is selected)
	LastSessionLength: number?, -- seconds of the current/most-recent session
	-- A session-only slot that is never persisted and is filtered out of the save-slot list. Set at
	-- creation and never mutated; see HasSaveSlots.PromiseSelectEphemeralSlot.
	IsEphemeral: boolean?,
}

-- The Summary is a structured table JSON-encoded into one attribute. A string is also accepted so a
-- legacy plain-string Summary (from before this was structured) loads without error -- it surfaces as
-- a string until the active slot's providers regenerate it as a table.
local function isSummaryValue(value: any): (boolean, string?)
	if value == nil or type(value) == "table" or type(value) == "string" then
		return true
	end
	return false, `Summary must be a table, string, or nil, got {typeof(value)}`
end

return AdorneeData.new({
	SlotId = AdorneeDataEntry.new("string", function(folder: Folder)
		return PropertyValue.new(folder, "Name")
	end),
	SlotIndex = 0,
	SlotName = AdorneeDataEntry.optionalAttribute("string", "SlotName"),
	CreatedTime = AdorneeDataEntry.optionalAttribute("number", "CreatedTime"),
	LastPlayedTime = AdorneeDataEntry.optionalAttribute("number", "LastPlayedTime"),
	Summary = AdorneeDataEntry.new(isSummaryValue, function(folder: Folder)
		return JSONAttributeValue.new(folder, "Summary", nil)
	end),
	TimePlayed = AdorneeDataEntry.optionalAttribute("number", "TimePlayed"),
	PlayCount = AdorneeDataEntry.optionalAttribute("number", "PlayCount"),
	LastSessionLength = AdorneeDataEntry.optionalAttribute("number", "LastSessionLength"),
	IsEphemeral = AdorneeDataEntry.optionalAttribute("boolean", "IsEphemeral"),
})
