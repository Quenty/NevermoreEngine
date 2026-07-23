--!strict
--[=[
	@class HasSaveSlots
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local Binder = require("Binder")
local Brio = require("Brio")
local DataStoreStage = require("DataStoreStage")
local HasSaveSlotsBase = require("HasSaveSlotsBase")
local HasSaveSlotsInterface = require("HasSaveSlotsInterface")
local InMemoryDataStore = require("InMemoryDataStore")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local PlayerBinder = require("PlayerBinder")
local PlayerDataStoreService = require("PlayerDataStoreService")
local Promise = require("Promise")
local Remoting = require("Remoting")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local SaveSlotExportUtils = require("SaveSlotExportUtils")
local ServiceBag = require("ServiceBag")
local TeleportDataService = require("TeleportDataService")

-- A summary provider contributes one named piece of a slot's Summary. It is called with the player and
-- the slot's DataStoreStage and returns an Observable of a JSON-serializable value. Providers are
-- aggregated into a table keyed by their registered name; see RegisterSummaryProvider and _setupSummary.
export type SummaryProvider = (Player, DataStoreStage.DataStoreStage) -> Observable.Observable<any>

-- A provider that errors (when called, or mid-stream) contributes this sentinel rather than stalling or
-- failing the whole aggregate; _setupSummary strips it back out before writing the Summary. Compared by
-- identity, so it never collides with a real value (even an empty table) a provider might emit.
local NONE = {}

-- An ephemeral slot carries no meaningful index -- a real slot's index positions it in the save list and
-- routes its store, neither of which applies to a throwaway slot. The authoritative "is ephemeral"
-- discriminator is the slot's own IsEphemeral property (see _isEphemeral), and every index-accounting path
-- skips ephemeral slots, so this value never routes anything and any number of ephemeral slots can coexist.
-- 0 is used because a real index is always >= 1 (DEFAULT_SLOT_INDEX is 1, PromiseCreateSlot rejects < 1).
local EPHEMERAL_SLOT_INDEX = 0

-- The caller-supplied fields for a new slot. SlotId and SlotIndex are assigned by PromiseCreateSlot
-- itself (from a fresh GUID and the slotIndex argument), so they are never taken from here.
export type SaveSlotCreateMetadata = {
	SlotName: string?,
	Summary: SaveSlotData.SaveSlotSummary?,
}

local HasSaveSlots = setmetatable({}, HasSaveSlotsBase)
HasSaveSlots.ClassName = "HasSaveSlots"
HasSaveSlots.__index = HasSaveSlots

export type HasSaveSlots =
	typeof(setmetatable(
		{} :: {
			_obj: Player,
			_serviceBag: ServiceBag.ServiceBag,
			_playerDataStoreService: any,
			_slotContainer: Folder,
			_slotMap: { [SaveSlotData.SlotId]: Folder },
			-- The in-memory stores backing ephemeral (session-only) slots, keyed by slot id. A slot's
			-- IsEphemeral property is the discriminator (see _isEphemeral); this holds the store objects a
			-- property can't. See PromiseSelectEphemeralSlot.
			_ephemeralStores: { [SaveSlotData.SlotId]: InMemoryDataStore.InMemoryDataStore },
			_loadPromise: Promise.Promise<{}>,
			_remoting: any,
			_dataStore: any,
			_systemStore: any,
			_metadataStore: any,
			_summaryProviders: ObservableMap.ObservableMap<string, SummaryProvider>,
			_lastActiveSlotId: SaveSlotData.SlotId?,
			_teleportDataService: any,
			_playSessionSlotId: SaveSlotData.SlotId?,
			_playSessionStart: number?,
			_playSessionLastFlush: number?,
		},
		{} :: typeof({ __index = HasSaveSlots })
	))
	& HasSaveSlotsBase.HasSaveSlotsBase

function HasSaveSlots.new(player: Player, serviceBag: ServiceBag.ServiceBag): HasSaveSlots
	local self: HasSaveSlots = setmetatable(HasSaveSlotsBase.new(player, serviceBag) :: any, HasSaveSlots)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._playerDataStoreService = self._serviceBag:GetService(PlayerDataStoreService)
	self._teleportDataService = self._serviceBag:GetService(TeleportDataService)

	self._slotContainer = self._maid:Add(Instance.new("Folder"))
	self._slotContainer.Name = SaveSlotConstants.METADATA_CONTAINER_NAME
	self._slotContainer.Archivable = false
	self._slotContainer.Parent = self._obj

	self._slotMap = {}
	self._ephemeralStores = {}

	self._summaryProviders = self._maid:Add(ObservableMap.new())

	self._loadPromise = self._maid:GivePromise(self:_promiseLoadSlots())

	self._remoting = self._maid:Add(Remoting.Server.new(self._obj, "HasSaveSlots"))

	self:_setupSummary()
	self:_setupPlaytimeTracking()
	self:_setupRemotes()

	self._maid:GiveTask(HasSaveSlotsInterface.Server:Implement(self._obj, self))

	return self
end

--[=[
	Observes the [DataStoreStage] for the active slot as a [Brio]
]=]
function HasSaveSlots.ObserveActiveSlotStoreBrio(
	self: HasSaveSlots
): Observable.Observable<Brio.Brio<DataStoreStage.DataStoreStage>>
	return Rx.fromPromise(self._loadPromise):Pipe({
		Rx.switchMap(function()
			return self.ActiveSlotId
				:ObserveBrio(function(slotId: SaveSlotData.SlotId?)
					return (slotId ~= nil)
				end)
				:Pipe({
					RxBrioUtils.map(function(slotId: SaveSlotData.SlotId)
						return self:_getSlotStore(slotId)
					end) :: any,
				}) :: any
		end) :: any,
	}) :: any
end

--[=[
	Returns the [DataStoreStage] for the active slot
]=]
function HasSaveSlots.PromiseActiveSlotStore(self: HasSaveSlots): Promise.Promise<DataStoreStage.DataStoreStage?>
	return (self._loadPromise :: any):Then(function()
		if not self.ActiveSlotId.Value then
			return (Promise :: any).resolved(nil)
		end
		return self:_getSlotStore(self.ActiveSlotId.Value)
	end)
end

--[=[
	Promises that all slots have loaded
]=]
function HasSaveSlots.PromiseSlotsLoaded(self: HasSaveSlots): Promise.Promise<any>
	return self._loadPromise
end

--[=[
	Returns whether the slot with the given ID exists
]=]
function HasSaveSlots.PromiseHasSlot(self: HasSaveSlots, slotId: SaveSlotData.SlotId?): Promise.Promise<boolean>
	return (self._loadPromise :: any):Then(function()
		return slotId and ((self._slotMap[slotId] :: Folder?) ~= nil)
	end)
end

--[=[
	Selects the slot with the given ID
]=]
function HasSaveSlots.PromiseSelectSlot(self: HasSaveSlots, slotId: SaveSlotData.SlotId): Promise.Promise<any>
	return (self._loadPromise :: any):Then(function()
		if slotId == self.ActiveSlotId.Value then
			return -- Already set
		end

		local slot = self._slotMap[slotId]
		if not slot then
			return (Promise :: any).rejected(`Slot \{{slotId}\} not found`)
		end

		local function setSlot()
			self.ActiveSlotId.Value = slotId
			SaveSlotData.LastPlayedTime:Set(slot, os.time())
		end

		-- Initialize or save and switch
		if self.ActiveSlotId.Value == nil then
			setSlot()
			return
		end

		-- Leaving an ephemeral slot has nothing to persist, so switch without a datastore flush (the flush
		-- exists to save the outgoing slot's progress, and an ephemeral slot has none).
		if self:_isEphemeral(self.ActiveSlotId.Value) then
			setSlot()
			return
		end

		return self._dataStore:Save():Then(setSlot)
	end)
end

--[=[
	Clears the active slot selection, returning the player to a no-slot state --
	the counterpart to [HasSaveSlots.PromiseSelectSlot], backing a "back to menu"
	affordance. The active slot's progress is flushed first (mirroring the save
	PromiseSelectSlot runs when switching away), and the last-active slot is
	remembered, so [HasSaveSlots.PromiseSelectLastSaveSlot] can resume it later.
	A no-op when no slot is active.
]=]
function HasSaveSlots.PromiseDeselectSlot(self: HasSaveSlots): Promise.Promise<()>
	return (self._loadPromise :: any):Then(function()
		if self.ActiveSlotId.Value == nil then
			return -- Already deselected
		end

		-- An ephemeral slot has nothing to flush, so clear it without a datastore save.
		if self:_isEphemeral(self.ActiveSlotId.Value) then
			self.ActiveSlotId.Value = nil
			return
		end

		return self._dataStore:Save():Then(function()
			self.ActiveSlotId.Value = nil
		end)
	end)
end

--[=[
	Creates a slot at the given index
]=]
function HasSaveSlots.PromiseCreateSlot(
	self: HasSaveSlots,
	slotIndex: number,
	metadata: SaveSlotCreateMetadata?
): Promise.Promise<SaveSlotData.SlotId>
	return (self._loadPromise :: any):Then(function()
		if (slotIndex < 1) or (slotIndex > self.MaxSlotCount.Value) then
			return (Promise :: any).rejected(`Index must be in range [1, {self.MaxSlotCount.Value}]`)
		end

		for existingSlotId, slot in self._slotMap do
			if self:_isEphemeral(existingSlotId) then
				continue -- ephemeral slots carry no meaningful index; never let one block a real index
			end
			if slotIndex == SaveSlotData.SlotIndex:Get(slot) then
				return (Promise :: any).rejected(`Slot {slotIndex} already exists`)
			end
		end

		local slotId = HttpService:GenerateGUID(false)
		local data = {
			SlotId = slotId,
			SlotIndex = slotIndex,
			SlotName = (metadata and metadata.SlotName) or `Slot {slotIndex}`,
			CreatedTime = os.time(),
			Summary = metadata and metadata.Summary,
		}

		self:_buildSlot(slotId, data, true)
		return slotId
	end)
end

--[=[
	Exports a slot's saved data into a plain, serializable [SaveSlotExportUtils.SaveSlotExport].
	Rejects the main/default slot: its store is the player's shared root datastore, so exporting it
	would leak the SaveSlots system data and universe-scoped global data living alongside it. Only
	isolated non-main slot substores are exportable.

	@param slotId SlotId
	@return Promise<SaveSlotExportUtils.SaveSlotExport>
]=]
function HasSaveSlots.PromiseExportSlot(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId
): Promise.Promise<SaveSlotExportUtils.SaveSlotExport>
	return (self._loadPromise :: any):Then(function()
		local slot = self._slotMap[slotId]
		if not slot then
			return (Promise :: any).rejected(`Slot \{{slotId}\} not found`)
		end

		if SaveSlotExportUtils.isMainSlotIndex(SaveSlotData.SlotIndex:Get(slot)) then
			return (Promise :: any).rejected("Cannot export the main slot")
		end

		local metadata = SaveSlotData:Get(slot)
		return self:_getSlotStore(slotId):LoadAll({}):Then(function(sourceData)
			local data = if type(sourceData) == "table" then table.clone(sourceData) else {}
			return SaveSlotExportUtils.create(data, metadata.SlotName, metadata.Summary)
		end)
	end)
end

--[=[
	Imports an exported slot into a fresh slot at the lowest free non-main index, seeding the new
	slot's store with the exported data. Never uses the main/default index -- importing onto the
	shared root store would wipe the player's global data. Resolves to the new slot's id. Rejects a
	malformed export, or when no non-main index is free.

	@param export SaveSlotExportUtils.SaveSlotExport
	@return Promise<SlotId>
]=]
function HasSaveSlots.PromiseImportSlot(
	self: HasSaveSlots,
	export: SaveSlotExportUtils.SaveSlotExport
): Promise.Promise<SaveSlotData.SlotId>
	return (self._loadPromise :: any):Then(function()
		if not SaveSlotExportUtils.isSaveSlotExport(export) then
			return (Promise :: any).rejected("Bad save slot export")
		end

		-- Lowest free index strictly above the main slot: an imported slot must never occupy the
		-- default index, whose store is the shared root datastore.
		local usedIndices = {}
		for existingSlotId, slot in self._slotMap do
			if not self:_isEphemeral(existingSlotId) then
				usedIndices[SaveSlotData.SlotIndex:Get(slot)] = true
			end
		end
		local freeIndex = SaveSlotConstants.DEFAULT_SLOT_INDEX + 1
		while usedIndices[freeIndex] do
			freeIndex += 1
		end
		if freeIndex > self.MaxSlotCount.Value then
			return (Promise :: any).rejected("No free non-main slot index available")
		end

		return self:PromiseCreateSlot(freeIndex, {
			SlotName = export.slotName,
			Summary = export.summary,
		}):Then(function(newSlotId: SaveSlotData.SlotId)
			-- freeIndex is always > DEFAULT_SLOT_INDEX, so this store is an isolated substore
			-- (never the shared root); a plain Overwrite cannot touch system or global data.
			self:_getSlotStore(newSlotId):Overwrite(export.data)

			-- Flush so the imported slot survives a crash before the next autosave.
			return self._dataStore:Save():Then(function()
				return newSlotId
			end)
		end)
	end)
end

--[=[
	Duplicates the slot with the given ID into a new slot at the lowest free index,
	copying its saved data. Resolves to the new slot's id. The copy is not selected,
	its metadata (playtime, timestamps) starts fresh, and its name is suffixed with
	" (Copy)". Rejects when the source slot is missing or every index is in use.
]=]
function HasSaveSlots.PromiseDuplicateSlot(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId
): Promise.Promise<SaveSlotData.SlotId>
	return (self._loadPromise :: any):Then(function()
		local sourceSlot = self._slotMap[slotId]
		if not sourceSlot then
			return (Promise :: any).rejected(`Slot \{{slotId}\} not found`)
		end

		if self:_isEphemeral(slotId) then
			return (Promise :: any).rejected("Cannot duplicate an ephemeral slot")
		end

		-- Lowest free positive index, filling gaps left by deletions (mirrors PromiseSelectNewSaveSlot).
		local usedIndices = {}
		for existingSlotId, slot in self._slotMap do
			if not self:_isEphemeral(existingSlotId) then
				usedIndices[SaveSlotData.SlotIndex:Get(slot)] = true
			end
		end
		local freeIndex = 1
		while usedIndices[freeIndex] do
			freeIndex += 1
		end
		if freeIndex > self.MaxSlotCount.Value then
			return (Promise :: any).rejected("All slots are already in use")
		end

		local sourceMetadata = SaveSlotData:Get(sourceSlot)

		-- Read the source's saved data before creating the copy so a read failure leaves no orphan slot.
		return self:_getSlotStore(slotId):LoadAll({}):Then(function(sourceData)
			-- The default slot shares the player's root store with the SaveSlots system data. Never carry
			-- that system key across into the copy's saved data.
			local slotData = if type(sourceData) == "table" then table.clone(sourceData) else {}
			slotData[SaveSlotConstants.SYSTEM_STORE_KEY] = nil

			return self:PromiseCreateSlot(freeIndex, {
				SlotName = `{sourceMetadata.SlotName} (Copy)`,
				Summary = sourceMetadata.Summary,
			}):Then(function(newSlotId: SaveSlotData.SlotId)
				local destStore = self:_getSlotStore(newSlotId)

				if destStore == self._dataStore then
					-- The copy is the default slot, whose store is the shared root. Merge so the SaveSlots
					-- system store living alongside it survives (a plain Overwrite would wipe it).
					destStore:OverwriteMerge(slotData)
				else
					destStore:Overwrite(slotData)
				end

				-- Flush so the duplicated data survives a crash before the next autosave.
				return self._dataStore:Save():Then(function()
					return newSlotId
				end)
			end)
		end)
	end)
end

--[=[
	Deletes the slot with the given ID
]=]
function HasSaveSlots.PromiseDeleteSlot(self: HasSaveSlots, slotId: SaveSlotData.SlotId): Promise.Promise<any>
	return (self._loadPromise :: any):Then(function()
		if slotId == self.ActiveSlotId.Value then
			return (Promise :: any).rejected("Cannot delete active slot")
		end

		local slot = self._slotMap[slotId]
		if not slot then
			return (Promise :: any).rejected(`Slot \{{slotId}\} not found`)
		end

		self._maid[slotId] = nil

		-- The continue pointer must not outlive its slot. When the deleted slot is the one the player
		-- would resume on (e.g. the just-deselected active slot, or a never-reselected last-active),
		-- clear the last-active memory so "Continue" stops offering a slot that no longer exists.
		if slotId == self._lastActiveSlotId then
			self._lastActiveSlotId = nil
			self.LastActiveSlotId.Value = nil
		end

		-- Wipe default slot
		local slotIndex = SaveSlotData.SlotIndex:Get(slot)
		local deletePromise = nil

		if slotIndex == SaveSlotConstants.DEFAULT_SLOT_INDEX then
			deletePromise = self._dataStore:PromiseKeyList():Then(function(keys)
				for _, key in keys do
					if key ~= SaveSlotConstants.SYSTEM_STORE_KEY then
						self._dataStore:Delete(key)
					end
				end
				self._metadataStore:Delete(slotId)
			end)
		else
			-- Or delete slot from substore
			self._systemStore:GetSubStore(SaveSlotConstants.SLOT_STORE_KEY):Delete(slotId)
			self._metadataStore:Delete(slotId)
			deletePromise = (Promise :: any).resolved()
		end

		-- Flush the deletion to prevent stale reads
		return deletePromise:Then(function()
			return self._dataStore:Save()
		end)
	end)
end

--[=[
	Deletes every slot for the player and clears the active/last-active
	selection, resetting the player to a fresh state. Resolves once all slots
	are gone.
]=]
function HasSaveSlots.PromiseDeleteAllSlots(self: HasSaveSlots): Promise.Promise<any>
	return (self._loadPromise :: any):Then(function()
		-- Clear the selection first so the previously active slot is deletable
		self.ActiveSlotId.Value = nil
		self._lastActiveSlotId = nil
		self.LastActiveSlotId.Value = nil

		local slotIds = {}
		for slotId in self._slotMap do
			table.insert(slotIds, slotId)
		end

		-- Delete sequentially to avoid concurrent datastore saves
		local promise = (Promise :: any).resolved()
		for _, slotId in slotIds do
			promise = promise:Then(function()
				return self:PromiseDeleteSlot(slotId)
			end)
		end
		return promise
	end)
end

--[=[
	Resets the slot with the given id to a fresh empty one -- equivalent to deleting the slot
	and creating a new one at the same index. The slot keeps its index and name; its saved data
	and metadata (timestamps) start fresh. Resolves to the new slot id.

	When the reset slot is the active slot, the selection clears and then reselects the fresh
	slot: everything bound to [HasSaveSlots.ObserveActiveSlotStoreBrio] tears down as the
	selection clears and rebuilds against the empty store on reselect, so consumers reset
	reactively without wiping their own state. A non-active slot is left unselected, and its
	"Continue" pointer (when it was the last-active slot) is carried across to the fresh id so
	the reset slot stays resumable. Rejects when the slot is missing.
]=]
function HasSaveSlots.PromiseResetSlot(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId
): Promise.Promise<SaveSlotData.SlotId>
	return (self._loadPromise :: any):Then(function(): any
		local slot = self._slotMap[slotId]
		if not slot then
			return (Promise :: any).rejected(`Slot \{{slotId}\} not found`)
		end

		if self:_isEphemeral(slotId) then
			return (Promise :: any).rejected("Cannot reset an ephemeral slot")
		end

		local metadata = SaveSlotData:Get(slot)
		local wasActive = (slotId == self.ActiveSlotId.Value)
		-- PromiseDeleteSlot clears the continue pointer when it targets the last-active slot; capture it
		-- now so the non-active path can move it onto the fresh slot id below.
		local wasLastActive = (slotId == self._lastActiveSlotId)

		if wasActive then
			-- Clear the selection so the slot is deletable, skipping the deselect flush that would
			-- persist progress we are about to delete.
			self.ActiveSlotId.Value = nil
		end

		return self:PromiseDeleteSlot(slotId)
			:Then(function()
				return self:PromiseCreateSlot(metadata.SlotIndex, { SlotName = metadata.SlotName })
			end)
			:Then(function(newSlotId: SaveSlotData.SlotId)
				if wasActive then
					-- Reselecting restores the continue pointer via the ActiveSlotId hook.
					return self:PromiseSelectSlot(newSlotId):Then(function()
						return newSlotId
					end)
				end

				-- Non-active reset never reselects, so carry the resume pointer onto the fresh id
				-- ourselves when this slot was the one "Continue" would resume.
				if wasLastActive then
					self._lastActiveSlotId = newSlotId
					self.LastActiveSlotId.Value = newSlotId
				end

				return newSlotId
			end)
	end)
end

--[=[
	Resets the active slot to a fresh empty one -- see [HasSaveSlots.PromiseResetSlot]. The slot
	keeps its index and name; its saved data and metadata (timestamps) start fresh, and the fresh
	slot stays selected. Resolves to the new slot id, or nil when no slot is active.
]=]
function HasSaveSlots.PromiseResetActiveSlot(self: HasSaveSlots): Promise.Promise<SaveSlotData.SlotId?>
	return (self._loadPromise :: any):Then(function(): any
		local slotId = self.ActiveSlotId.Value
		if not slotId then
			return nil -- Nothing selected to reset
		end

		return self:PromiseResetSlot(slotId)
	end)
end

--[=[
	Sets the metadata for the slot with the given ID
]=]
function HasSaveSlots.PromiseSetSlotMetadata(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId,
	data: SaveSlotData.SaveSlotMetadata
): Promise.Promise<any>
	if data.SlotId and (data.SlotId ~= slotId) then
		return (Promise :: any).rejected("SlotId is locked")
	end

	return (self._loadPromise :: any):Then(function()
		local slot = self._slotMap[slotId]

		-- Routing depends on immutable indices to distinguish the default slot
		if data.SlotIndex and (data.SlotIndex ~= SaveSlotData.SlotIndex:Get(slot)) then
			return (Promise :: any).rejected("SlotIndex is locked")
		end

		SaveSlotData:Set(slot, data)
	end)
end

--[=[
	Gets the metadata for the slot with the given ID
]=]
function HasSaveSlots.PromiseGetSlotMetadata(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId
): Promise.Promise<SaveSlotData.SaveSlotMetadata?>
	return (self._loadPromise :: any):Then(function()
		local slot = self._slotMap[slotId]
		return (Promise :: any).resolved(slot and SaveSlotData:Get(slot))
	end)
end

--[=[
	Returns the slot ID from the given index
]=]
function HasSaveSlots.PromiseSlotIdFromIndex(
	self: HasSaveSlots,
	slotIndex: number
): Promise.Promise<SaveSlotData.SlotId?>
	return (self._loadPromise :: any):Then(function()
		for slotId, slot in self._slotMap do
			if self:_isEphemeral(slotId) then
				continue -- ephemeral slots are never addressable by index
			end
			if slotIndex == SaveSlotData.SlotIndex:Get(slot) then
				return (Promise :: any).resolved(slotId)
			end
		end
		return (Promise :: any).resolved(nil)
	end)
end

--[=[
	Gets the last active slot ID
]=]
function HasSaveSlots.PromiseLastActiveSlotId(self: HasSaveSlots): Promise.Promise<SaveSlotData.SlotId?>
	return (self._loadPromise :: any):Then(function()
		return self.ActiveSlotId.Value or self._lastActiveSlotId
	end)
end

--[=[
	Selects the player's last active slot if one still exists, resolving to the
	selected slot id -- or nil when there is no slot to continue on. Backs a
	"Continue" affordance that every save-slot consumer tends to need.
]=]
function HasSaveSlots.PromiseSelectLastSaveSlot(self: HasSaveSlots): Promise.Promise<SaveSlotData.SlotId?>
	return self:PromiseLastActiveSlotId():Then(function(lastActiveSlotId: SaveSlotData.SlotId?)
		if not lastActiveSlotId then
			return nil
		end

		return self:PromiseHasSlot(lastActiveSlotId):Then(function(hasLastSlot: boolean)
			if not hasLastSlot then
				return nil
			end

			return self:PromiseSelectSlot(lastActiveSlotId):Then(function()
				return lastActiveSlotId
			end)
		end)
	end)
end

--[=[
	Creates a new slot at the lowest free index and selects it, resolving to the
	new slot id -- or nil when every slot is already in use. Backs a "New Game"
	affordance.
]=]
function HasSaveSlots.PromiseSelectNewSaveSlot(self: HasSaveSlots): Promise.Promise<SaveSlotData.SlotId?>
	return (self._loadPromise :: any):Then(function(): any
		local usedIndices = {}
		for existingSlotId, slot in self._slotMap do
			if not self:_isEphemeral(existingSlotId) then
				usedIndices[SaveSlotData.SlotIndex:Get(slot)] = true
			end
		end

		-- Lowest free positive index. Fills gaps left by deletions (delete slot 2 of
		-- [1,2,3] and the next new slot reuses index 2). With a finite MaxSlotCount this
		-- returns nil once [1, MaxSlotCount] is full; with an unbounded count (math.huge)
		-- there is always a next integer, so it never returns nil.
		local freeIndex = 1
		while usedIndices[freeIndex] do
			freeIndex += 1
		end

		if freeIndex > self.MaxSlotCount.Value then
			return nil
		end

		return self:PromiseCreateSlot(freeIndex):Then(function(slotId: SaveSlotData.SlotId)
			return self:PromiseSelectSlot(slotId):Then(function()
				return slotId
			end)
		end)
	end)
end

--[=[
	Creates a fresh ephemeral slot and selects it, resolving to its id. An ephemeral slot is selectable and
	active exactly like a real one -- it drives [HasSaveSlots.ObserveActiveSlotStoreBrio], summaries, and
	playtime the same way -- but it is never persisted: no metadata is written, its data store is in-memory,
	it is kept out of the replicated slot list, and it is torn down the moment it stops being the active slot.
	Selecting it also never disturbs the persisted active-slot pointer or the "Continue" target, so the real
	slot the player came from resumes untouched afterward. Backs a throwaway session (e.g. exploring a lobby)
	that must leave no trace on save data.

	@param metadata SaveSlotCreateMetadata? -- optional SlotName/Summary for the in-memory slot
	@return Promise<SlotId>
]=]
function HasSaveSlots.PromiseSelectEphemeralSlot(
	self: HasSaveSlots,
	metadata: SaveSlotCreateMetadata?
): Promise.Promise<SaveSlotData.SlotId>
	return (self._loadPromise :: any):Then(function()
		local slotId = HttpService:GenerateGUID(false)
		local data = {
			SlotId = slotId,
			SlotIndex = EPHEMERAL_SLOT_INDEX,
			SlotName = (metadata and metadata.SlotName) or "Ephemeral",
			CreatedTime = os.time(),
			Summary = metadata and metadata.Summary,
		}

		self:_buildSlot(slotId, data, true, true)

		return self:PromiseSelectSlot(slotId):Then(function()
			return slotId
		end)
	end)
end

--[=[
	Registers a named summary provider. Every registered provider's current value is aggregated into
	the active slot's Summary, keyed by `name` (see [HasSaveSlots.PromiseGetSlotMetadata]). Registering
	the same name again replaces the previous provider. Returns a function that unregisters the provider
	(also give it to a [Maid]).

	@param name string
	@param provider SummaryProvider
	@return () -> ()
]=]
function HasSaveSlots.RegisterSummaryProvider(self: HasSaveSlots, name: string, provider: SummaryProvider): () -> ()
	assert(type(name) == "string", "Bad name")
	assert(type(provider) == "function", "Bad provider")

	return self._summaryProviders:Set(name, provider :: any)
end

-- Server realm hook for HasSaveSlotsBase: the incoming slot id is whatever the player teleported in
-- with, read from the unified TeleportDataService view. It is a promise because a client-initiated
-- teleport only reaches the server once the client replicates its arrived data. The slot id is a
-- client *request* -- fine here, because PromiseLoadSaveSlotFromTeleport re-validates ownership via
-- PromiseHasSlot before selecting it.
function HasSaveSlots.PromiseIncomingSlotId(self: HasSaveSlots): Promise.Promise<SaveSlotData.SlotId?>
	return self._teleportDataService
		:PromiseArrivedValue(self._obj, SaveSlotConstants.TELEPORT_DATA_SLOT_KEY)
		:Then(function(slotId): SaveSlotData.SlotId?
			if type(slotId) == "string" then
				return slotId
			end
			return nil
		end)
end

function HasSaveSlots._promiseLoadSlots(self: HasSaveSlots): Promise.Promise<{}>
	return self._playerDataStoreService:PromiseDataStore(self._obj):Then(function(dataStore)
		self._dataStore = dataStore
		self._systemStore = dataStore:GetSubStore(SaveSlotConstants.SYSTEM_STORE_KEY)
		self._metadataStore = self._systemStore:GetSubStore(SaveSlotConstants.METADATA_STORE_KEY)

		return self._metadataStore:LoadAll({}):Then(function(metadata)
			for slotId, data in metadata do
				self:_buildSlot(slotId, data)
			end

			return self._systemStore:Load("activeSlotId"):Then(function(activeId: SaveSlotData.SlotId?)
				self._lastActiveSlotId = activeId
				self.LastActiveSlotId.Value = activeId

				-- The persisted active-slot pointer and the replicated "Continue" target only ever track real
				-- slots. This replaces StoreOnValueChange so an ephemeral selection is invisible to both:
				-- entering one leaves them pinned to the real slot, and the ephemeral slot is torn down the
				-- moment it stops being active. We track the id we are leaving to know which of those to do.
				local previousActiveSlotId: SaveSlotData.SlotId? = activeId

				self._maid:GiveTask(self.ActiveSlotId.Changed:Connect(function()
					local active = self.ActiveSlotId.Value
					local leftSlotId = previousActiveSlotId
					-- Read before the retire below, while the outgoing slot is still in the map.
					local leavingEphemeral = self:_isEphemeral(leftSlotId)
					previousActiveSlotId = active

					-- Persist the pointer + remember the Continue target only for real-slot transitions
					-- (real -> real, real -> nil deselect, nil -> real). Skip both ephemeral cases: entering an
					-- ephemeral slot must stay invisible to persistence, and leaving one back to no slot must
					-- leave the real pointer pinned where it was.
					local enteringEphemeral = self:_isEphemeral(active)
					local leavingEphemeralToMenu = leavingEphemeral and active == nil
					if not (enteringEphemeral or leavingEphemeralToMenu) then
						self._systemStore:Store("activeSlotId", active)
						if active ~= nil then
							self._lastActiveSlotId = active
							self.LastActiveSlotId.Value = active
						end
					end

					-- An ephemeral slot exists only while it is the active slot; retire the one we just left.
					if leavingEphemeral and leftSlotId ~= active then
						self:_destroyEphemeralSlot(leftSlotId :: SaveSlotData.SlotId)
					end
				end))
			end)
		end)
	end)
end

function HasSaveSlots._getSlotStore(self: HasSaveSlots, slotId: SaveSlotData.SlotId): DataStoreStage.DataStoreStage
	local ephemeralStore = self._ephemeralStores[slotId]
	if ephemeralStore then
		return ephemeralStore
	end

	local slot = self._slotMap[slotId]
	if slot and (SaveSlotData.SlotIndex:Get(slot) == SaveSlotConstants.DEFAULT_SLOT_INDEX) then
		return self._dataStore
	end
	return self._systemStore:GetSubStore(SaveSlotConstants.SLOT_STORE_KEY):GetSubStore(slotId)
end

local MUTABLE_METADATA_KEYS =
	{ "SlotName", "CreatedTime", "LastPlayedTime", "Summary", "TimePlayed", "PlayCount", "LastSessionLength" }

function HasSaveSlots._buildSlot(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId,
	data: SaveSlotData.SaveSlotMetadata,
	isNew: boolean?,
	isEphemeral: boolean?
): ()
	local maid = Maid.new()
	self._maid[slotId] = maid

	local slot = maid:Add(Instance.new("Folder"))
	slot.Name = slotId
	slot.Archivable = false

	local attributes = SaveSlotData:Create(slot)
	attributes.SlotId.Value = slotId
	attributes.SlotIndex.Value = data.SlotIndex

	if isEphemeral then
		-- Ephemeral: seed the metadata in memory with no write-back wiring, back the slot with an in-memory
		-- store, and deliberately leave the folder unparented so it never joins the replicated slot container
		-- (SaveSlotDataService lists that container's children -- an ephemeral slot must not surface as a save).
		--
		-- The in-memory store's lifetime is owned by this slot's maid (which is in turn owned by self._maid),
		-- so it is Destroyed -- and becomes GC-eligible -- the instant the slot is retired (_destroyEphemeralSlot)
		-- or the player unbinds. Nothing outside this object holds a lasting reference: while the slot is active
		-- ObserveActiveSlotStoreBrio hands it out inside a Brio that dies when the slot deselects, releasing it.
		attributes.IsEphemeral.Value = true
		self._ephemeralStores[slotId] = maid:Add(InMemoryDataStore.new(slotId))

		for _, key in MUTABLE_METADATA_KEYS do
			attributes[key].Value = data[key]
		end

		self._slotMap[slotId] = slot
		maid:GiveTask(function()
			self._slotMap[slotId] = nil
			self._ephemeralStores[slotId] = nil
		end)
		return
	end

	local metadataStore = self._metadataStore:GetSubStore(slotId)

	-- Store immutable SlotIndex once on creation
	if isNew then
		metadataStore:Store("SlotIndex", data.SlotIndex)
	end

	-- Store mutable metadata on change
	for _, key in MUTABLE_METADATA_KEYS do
		attributes[key].Value = data[key]
		maid:GiveTask(metadataStore:StoreOnValueChange(key, attributes[key]))

		if isNew then
			metadataStore:Store(key, attributes[key].Value)
		end
	end

	slot.Parent = self._slotContainer

	self._slotMap[slotId] = slot

	maid:GiveTask(function()
		self._slotMap[slotId] = nil
	end)
end

-- Whether the slot is an ephemeral (session-only, never-persisted) slot. The slot's own IsEphemeral property
-- is the single source of truth (set once at creation in _buildSlot); nil-safe so callers can pass a possibly
-- nil active-slot id directly.
function HasSaveSlots._isEphemeral(self: HasSaveSlots, slotId: SaveSlotData.SlotId?): boolean
	if slotId == nil then
		return false
	end
	local slot = self._slotMap[slotId] :: Folder?
	return slot ~= nil and SaveSlotData.IsEphemeral:Get(slot) == true
end

-- Tears down the ephemeral slot's maid (folder, in-memory store, and every map entry via the teardown task
-- registered in _buildSlot). Idempotent -- clearing an already-cleared maid key is a no-op.
function HasSaveSlots._destroyEphemeralSlot(self: HasSaveSlots, slotId: SaveSlotData.SlotId): ()
	self._maid[slotId] = nil
end

function HasSaveSlots._setupSummary(self: HasSaveSlots): ()
	self._maid:GiveTask(
		self:ObserveActiveSlotStoreBrio():Subscribe(function(brio: Brio.Brio<DataStoreStage.DataStoreStage>)
			if brio:IsDead() then
				return
			end

			local activeSlotId = self.ActiveSlotId.Value
			local activeSlot = activeSlotId and self._slotMap[activeSlotId]
			if not activeSlot then
				return
			end

			local maid, slotStore = brio:ToMaidAndValue()

			maid:GiveTask(self:_observeSummary(slotStore):Subscribe(function(summary: SaveSlotData.SaveSlotSummary)
				-- An empty aggregate (no providers, or every one errored/contributed nothing) clears the
				-- Summary rather than persisting an empty table.
				SaveSlotData.Summary:Set(activeSlot, if next(summary) ~= nil then summary else nil)
			end))
		end)
	)
end

-- Aggregates every registered summary provider's current value into one table keyed by provider name,
-- re-aggregating whenever a provider is registered or unregistered. Always emits a table (possibly
-- empty); providers that contribute nothing are simply absent from it.
function HasSaveSlots._observeSummary(
	self: HasSaveSlots,
	slotStore: DataStoreStage.DataStoreStage
): Observable.Observable<SaveSlotData.SaveSlotSummary>
	return self._summaryProviders:ObserveKeyList():Pipe({
		Rx.switchMap(function(names: { string })
			if #names == 0 then
				return Rx.of({}) :: any
			end

			local observablesByName = {}
			for _, name in names do
				observablesByName[name] = self:_observeProviderValue(name, slotStore)
			end

			return Rx.combineLatest(observablesByName):Pipe({
				Rx.map(function(valuesByName: { [string]: any }): SaveSlotData.SaveSlotSummary
					local summary = {}
					for name, value in valuesByName do
						if value ~= NONE then
							summary[name] = value
						end
					end
					return summary
				end) :: any,
			}) :: any
		end) :: any,
	}) :: any
end

-- Observes the value contributed by the provider registered under `name`, isolating it: an error when
-- calling the provider, a non-Observable return, or a mid-stream error all resolve to the NONE sentinel
-- so one bad provider neither stalls nor fails the aggregate. Tracks provider replacement at `name`.
function HasSaveSlots._observeProviderValue(
	self: HasSaveSlots,
	name: string,
	slotStore: DataStoreStage.DataStoreStage
): Observable.Observable<any>
	return self._summaryProviders:ObserveAtKey(name):Pipe({
		Rx.switchMap(function(provider: SummaryProvider?)
			if not provider then
				return Rx.of(NONE) :: any
			end

			local success, observable = pcall(provider, self._obj, slotStore)
			if not success then
				warn(`[HasSaveSlots] Summary provider {name} errored: {observable}`)
				return Rx.of(NONE) :: any
			end

			if not Observable.isObservable(observable) then
				warn(`[HasSaveSlots] Summary provider {name} did not return an Observable`)
				return Rx.of(NONE) :: any
			end

			return (observable :: any):Pipe({
				Rx.catchError(function(err)
					warn(`[HasSaveSlots] Summary provider {name} stream errored: {err}`)
					return Rx.of(NONE)
				end) :: any,
			})
		end) :: any,
	}) :: any
end

--[=[
	Accrues per-slot playtime automatically. A "session" spans the time a slot is the active slot:
	selecting a slot begins one (bumping PlayCount), and deselecting, switching, or unbinding ends
	it. Elapsed wall time is folded into the slot's TimePlayed from a datastore saving callback, so
	it persists on exactly the cadence the data is written -- always fresh at save time, with no
	separate timer -- and again at each session boundary.
]=]
function HasSaveSlots._setupPlaytimeTracking(self: HasSaveSlots): ()
	self._playSessionSlotId = nil
	self._playSessionStart = nil
	self._playSessionLastFlush = nil

	-- The active slot bounds the session: end the previous one (if any) and begin the new one.
	self._maid:GiveTask(self.ActiveSlotId.Changed:Connect(function()
		self:_endPlaySession()

		local activeSlotId = self.ActiveSlotId.Value
		if activeSlotId ~= nil then
			self:_beginPlaySession(activeSlotId)
		end
	end))

	-- Fold accrued time into TimePlayed just before every save so the written value is current. The
	-- callback runs before the save serializes staged data (see DataStore._syncData), so the flush is
	-- captured by that same save -- including the final save-on-leave.
	self._maid:GivePromise(self._loadPromise):Then(function()
		self._maid:GiveTask(self._dataStore:AddSavingCallback(function()
			self:_flushPlaytime()
		end))
	end)

	-- Best-effort flush on unbind for the case where the binder tears down before that final save.
	self._maid:GiveTask(function()
		self:_endPlaySession()
	end)
end

function HasSaveSlots._beginPlaySession(self: HasSaveSlots, slotId: SaveSlotData.SlotId): ()
	local now = os.time()
	self._playSessionSlotId = slotId
	self._playSessionStart = now
	self._playSessionLastFlush = now

	local slot = self._slotMap[slotId]
	if slot then
		SaveSlotData.PlayCount:Set(slot, (SaveSlotData.PlayCount:Get(slot) or 0) + 1)
	end
end

function HasSaveSlots._flushPlaytime(self: HasSaveSlots): ()
	local slotId = self._playSessionSlotId
	if slotId == nil then
		return
	end

	local slot = self._slotMap[slotId]
	if not slot then
		return
	end

	local now = os.time()

	-- Add only the time since the last flush so repeated flushes within a session never double count.
	local sinceFlush = now - (self._playSessionLastFlush or now)
	if sinceFlush > 0 then
		SaveSlotData.TimePlayed:Set(slot, (SaveSlotData.TimePlayed:Get(slot) or 0) + sinceFlush)
		self._playSessionLastFlush = now
	end

	SaveSlotData.LastSessionLength:Set(slot, now - (self._playSessionStart or now))
end

function HasSaveSlots._endPlaySession(self: HasSaveSlots): ()
	if self._playSessionSlotId == nil then
		return
	end

	self:_flushPlaytime()
	self._playSessionSlotId = nil
	self._playSessionStart = nil
	self._playSessionLastFlush = nil
end

function HasSaveSlots._setupRemotes(self: HasSaveSlots): ()
	self._maid:GiveTask(self._remoting.PromiseHasSlot:Bind(function(remotePlayer, ...)
		if remotePlayer == self._obj then
			return self:PromiseHasSlot(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseSelectSlot:Bind(function(remotePlayer, ...)
		if remotePlayer == self._obj then
			return self:PromiseSelectSlot(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseCreateSlot:Bind(function(remotePlayer, ...)
		if remotePlayer == self._obj then
			return self:PromiseCreateSlot(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseDeleteSlot:Bind(function(remotePlayer, ...)
		if remotePlayer == self._obj then
			return self:PromiseDeleteSlot(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseSetSlotMetadata:Bind(function(remotePlayer, ...)
		if remotePlayer == self._obj then
			return self:PromiseSetSlotMetadata(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseGetSlotMetadata:Bind(function(remotePlayer, ...)
		if remotePlayer == self._obj then
			return self:PromiseGetSlotMetadata(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseSlotIdFromIndex:Bind(function(remotePlayer, ...)
		if remotePlayer == self._obj then
			return self:PromiseSlotIdFromIndex(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseLastActiveSlotId:Bind(function(remotePlayer)
		if remotePlayer == self._obj then
			return self:PromiseLastActiveSlotId()
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))
end

return PlayerBinder.new("HasSaveSlots", HasSaveSlots :: any) :: Binder.Binder<HasSaveSlots>
