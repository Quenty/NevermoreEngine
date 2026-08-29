--!strict
--[=[
	Pure helpers describing an exported save slot and the main-slot guard that keeps export/import
	away from the player's shared root datastore. See [HasSaveSlots.PromiseExportSlot] and
	[HasSaveSlots.PromiseImportSlot].

	@class SaveSlotExportUtils
]=]

local require = require(script.Parent.loader).load(script)

local SaveSlotConstants = require("SaveSlotConstants")
local Table = require("Table")

local SaveSlotExportUtils = {}

--[=[
	What an entry in the shared store may be loaded as.

	The two exist because one of the shared store's readers takes its key from the client: a teleport
	arrives carrying the key of the transferable ephemeral slot it is resuming, and the arrival path
	loads whatever is behind it. A share code handed to a friend must not be loadable that way, so the
	writer records which of the two it wrote and each reader accepts only its own kind.

	@interface SaveSlotExportKind
	.CODE "code" -- a share code, redeemable into a slot the owner keeps
	.TRANSFER "transfer" -- a live snapshot carried across a teleport, loadable from a client-presented key
	@within SaveSlotExportUtils
]=]
export type SaveSlotExportKind = "code" | "transfer"

SaveSlotExportUtils.Kind = Table.readonly({
	CODE = "code" :: SaveSlotExportKind,
	TRANSFER = "transfer" :: SaveSlotExportKind,
})

-- A slot's saved data plus the presentation metadata worth carrying with it. `data` is the merged,
-- serializable view of the slot's store; slotName/summary/timePlayed seed the imported slot's metadata
-- so a restored slot is still recognizable and still owns the playtime behind its progress. timePlayed
-- is absent from exports written before it was carried; those import with no accrued playtime, exactly
-- as they did when they were written. `kind` is absent on entries written before kinds existed; see
-- [SaveSlotExportUtils.canLoadAs] for how those are read.
export type SaveSlotExport = {
	data: { [string]: any },
	slotName: string?,
	summary: any?,
	timePlayed: number?,
	kind: SaveSlotExportKind?,
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
	if value.timePlayed ~= nil and type(value.timePlayed) ~= "number" then
		return false
	end
	if
		value.kind ~= nil
		and value.kind ~= SaveSlotExportUtils.Kind.CODE
		and value.kind ~= SaveSlotExportUtils.Kind.TRANSFER
	then
		return false
	end
	return true
end

--[=[
	Returns whether an entry read from the shared store may be loaded as the given kind.

	Entries written before kinds existed carry none, and are treated as share codes: back then the
	transfer path re-saved under the very key the code was minted as, so an untagged entry is
	indistinguishable from the code it started life as. Old codes therefore keep working, while the
	arrival path -- the one reading a client-presented key -- accepts nothing that was not explicitly
	written as a transfer.

	@param export SaveSlotExport
	@param kind SaveSlotExportKind
	@return boolean
]=]
function SaveSlotExportUtils.canLoadAs(export: SaveSlotExport, kind: SaveSlotExportKind): boolean
	if export.kind == nil then
		return kind == SaveSlotExportUtils.Kind.CODE
	end

	return export.kind == kind
end

--[=[
	Returns a copy of the export tagged as the given kind, for writing to the shared store.

	@param export SaveSlotExport
	@param kind SaveSlotExportKind
	@return SaveSlotExport
]=]
function SaveSlotExportUtils.withKind(export: SaveSlotExport, kind: SaveSlotExportKind): SaveSlotExport
	local copy = table.clone(export)
	copy.kind = kind
	return copy
end

--[=[
	Builds a [SaveSlotExport] from a slot's data table and its metadata.

	@param data { [string]: any }
	@param slotName string?
	@param summary any?
	@param timePlayed number? -- the source slot's accrued playtime, in seconds
	@return SaveSlotExport
]=]
function SaveSlotExportUtils.create(
	data: { [string]: any },
	slotName: string?,
	summary: any?,
	timePlayed: number?
): SaveSlotExport
	return {
		data = data,
		slotName = slotName,
		summary = summary,
		timePlayed = timePlayed,
	}
end

return SaveSlotExportUtils
