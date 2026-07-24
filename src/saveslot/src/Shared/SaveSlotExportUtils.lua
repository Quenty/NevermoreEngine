--!strict
--[=[
	Pure helpers describing an exported save slot and the main-slot guard that keeps export/import
	away from the player's shared root datastore. See [HasSaveSlots.PromiseExportSlot] and
	[HasSaveSlots.PromiseImportSlot].

	@class SaveSlotExportUtils
]=]

local require = require(script.Parent.loader).load(script)

local SaveSlotConstants = require("SaveSlotConstants")

local SaveSlotExportUtils = {}

-- A slot's saved data plus the presentation metadata worth carrying with it. `data` is the merged,
-- serializable view of the slot's store; slotName/summary seed the imported slot's metadata so a
-- restored slot is still recognizable.
export type SaveSlotExport = {
	data: { [string]: any },
	slotName: string?,
	summary: any?,
}

--[=[
	Returns whether the given index is the main/default slot -- the one whose store is the player's
	shared root datastore (it shares that key with the SaveSlots system data and universe-scoped
	global data). Export/import refuse this index in both directions.

	@param slotIndex number
	@return boolean
]=]
function SaveSlotExportUtils.isMainSlotIndex(slotIndex: number): boolean
	return slotIndex == SaveSlotConstants.DEFAULT_SLOT_INDEX
end

--[=[
	Returns whether the value is a well-formed [SaveSlotExport].

	@param value any
	@return boolean
]=]
function SaveSlotExportUtils.isSaveSlotExport(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	if type(value.data) ~= "table" then
		return false
	end
	if value.slotName ~= nil and type(value.slotName) ~= "string" then
		return false
	end
	return true
end

--[=[
	Builds a [SaveSlotExport] from a slot's data table and its metadata.

	@param data { [string]: any }
	@param slotName string?
	@param summary any?
	@return SaveSlotExport
]=]
function SaveSlotExportUtils.create(data: { [string]: any }, slotName: string?, summary: any?): SaveSlotExport
	return {
		data = data,
		slotName = slotName,
		summary = summary,
	}
end

return SaveSlotExportUtils
