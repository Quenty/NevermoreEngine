--!strict
--[=[
	The save slot system over a [DataStore], with no [Player] attached.

	This is the whole slot model -- the roster, the per-slot stores, selection, create/delete/reset,
	export/import, ephemeral slots and playtime -- expressed against an injected datastore rather than
	against a bound player. [HasSaveSlots] is the binder that owns one of these for a live player and
	supplies the player-shaped parts (replication, remotes, teleport data, summary providers).

	Splitting it out is what makes a slot reachable for a player who is not in this server: admin
	tooling borrows that player's datastore (see `PlayerDataStoreHandle`) and builds one of these over
	it, getting the same slot semantics with no [Player] instance in sight.

	The slot roster is still modelled as Folders with attributes, because that representation is what
	the client reads. Offline, those folders simply live in an unparented container and replicate to
	nobody.

	:::info
	Constructed with a *promise* of a datastore rather than a datastore, so every method can gate on
	the same load promise the player path always gated on. Callers do not have to wait before using it.
	:::

	@server
	@class HasSaveSlotsDataStore
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local BaseObject = require("BaseObject")
local Brio = require("Brio")
local DataStoreStage = require("DataStoreStage")
local InMemoryDataStore = require("InMemoryDataStore")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local SaveSlotCodeUtils = require("SaveSlotCodeUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local SaveSlotExportUtils = require("SaveSlotExportUtils")
local ValueObject = require("ValueObject")

-- The caller-supplied fields for a new slot. SlotId and SlotIndex are assigned by PromiseCreateSlot
-- itself (from a fresh GUID and the slotIndex argument), so they are never taken from here.
-- TimePlayed seeds the new slot's accrued playtime, which is what lets a copy of a slot (duplicate or
-- export/import) carry the playtime that belongs to the progress being copied.
export type SaveSlotCreateMetadata = {
	SlotName: string?,
	Summary: SaveSlotData.SaveSlotSummary?,
	TimePlayed: number?,
}

--[=[
	The state and collaborators this class cannot derive from a datastore alone.

	The four value objects are *borrowed*, never owned: the player path passes the ones backed by
	replicated player attributes, so writing them replicates, while offline tooling passes detached
	ones. Either way this class only reads and writes them, and never destroys them.

	@interface HasSaveSlotsDataStoreOptions
	.ActiveSlotId ValueObject<SlotId?>
	.LastActiveSlotId ValueObject<SlotId?>
	.ActiveTransferableEphemeralKey ValueObject<string?>
	.MaxSlotCount ValueObject<number>
	.SharedDataStoreService any -- SaveSlotSharedDataStoreService
	.PromisePreSelect ((SlotId) -> Promise<boolean>)? -- veto hook, defaults to allowing every selection
	.UserId number? -- identity for generated share codes
	.UserName string? -- identity for generated share codes
	.TrackPlaytime boolean? -- accrue play sessions from selection changes, defaults to true
	@within HasSaveSlotsDataStore
]=]
export type HasSaveSlotsDataStoreOptions = {
	ActiveSlotId: ValueObject.ValueObject<SaveSlotData.SlotId?>,
	LastActiveSlotId: ValueObject.ValueObject<SaveSlotData.SlotId?>,
	ActiveTransferableEphemeralKey: ValueObject.ValueObject<string?>,
	MaxSlotCount: ValueObject.ValueObject<number>,
	SharedDataStoreService: any,
	PromisePreSelect: ((SaveSlotData.SlotId) -> Promise.Promise<boolean>)?,
	UserId: number?,
	UserName: string?,
	TrackPlaytime: boolean?,
}

local HasSaveSlotsDataStore = {}
HasSaveSlotsDataStore.ClassName = "HasSaveSlotsDataStore"
HasSaveSlotsDataStore.__index = HasSaveSlotsDataStore
-- Runtime inheritance only, typed as `any`, and the inherited surface supplied structurally below.
-- [HasSaveSlots] names this type across every delegation, so intersecting the full BaseObject type
-- here overflows the old solver's complexity budget over there ("Code is too complex").
setmetatable(HasSaveSlotsDataStore :: any, BaseObject)

-- Minimal structural surface inherited from BaseObject. See the setmetatable note above.
type BaseObjectLike = {
	_maid: Maid.Maid,
	Destroy: (self: any) -> (),
}

export type HasSaveSlotsDataStore =
	typeof(setmetatable(
		{} :: {
			_slotContainer: Folder,
			_slotMap: { [SaveSlotData.SlotId]: Folder },
			-- The in-memory stores backing ephemeral (session-only) slots, keyed by slot id. A slot's
			-- IsEphemeral property is the discriminator (see _isEphemeral); this holds the store objects a
			-- property can't. See PromiseSelectEphemeralSlot.
			_ephemeralStores: { [SaveSlotData.SlotId]: InMemoryDataStore.InMemoryDataStore },
			-- The shared-store key each transferable ephemeral slot was loaded from, so a teleport can
			-- re-save its live state under that key and carry it forward. See PromiseSelectTransferableEphemeralSlot.
			_transferableEphemeralKeys: { [SaveSlotData.SlotId]: string },
			_codeGenerator: SaveSlotCodeUtils.CodeGenerator,
			_loadPromise: Promise.Promise<{}>,
			_dataStore: any,
			_systemStore: any,
			_metadataStore: any,
			_lastActiveSlotId: SaveSlotData.SlotId?,
			_sharedSaveSlotDataStoreService: any,
			_promisePreSelect: ((SaveSlotData.SlotId) -> Promise.Promise<boolean>)?,
			_userId: number?,
			_userName: string?,
			_playSessionSlotId: SaveSlotData.SlotId?,
			_playSessionStart: number?,
			_playSessionLastFlush: number?,

			ActiveSlotId: ValueObject.ValueObject<SaveSlotData.SlotId?>,
			LastActiveSlotId: ValueObject.ValueObject<SaveSlotData.SlotId?>,
			ActiveTransferableEphemeralKey: ValueObject.ValueObject<string?>,
			MaxSlotCount: ValueObject.ValueObject<number>,
			SlotContainerParent: ValueObject.ValueObject<Instance?>,
		},
		{} :: typeof({ __index = HasSaveSlotsDataStore })
	))
	& BaseObjectLike

--[=[
	Builds the slot system over a datastore that may not have loaded yet.

	@param promiseDataStore Promise<DataStore>
	@param options HasSaveSlotsDataStoreOptions
	@return HasSaveSlotsDataStore
]=]
function HasSaveSlotsDataStore.new(
	promiseDataStore: Promise.Promise<any>,
	options: HasSaveSlotsDataStoreOptions
): HasSaveSlotsDataStore
	local self: HasSaveSlotsDataStore = setmetatable(BaseObject.new() :: any, HasSaveSlotsDataStore)

	assert(promiseDataStore, "No promiseDataStore")
	assert(options, "No options")

	self.ActiveSlotId = assert(options.ActiveSlotId, "No ActiveSlotId")
	self.LastActiveSlotId = assert(options.LastActiveSlotId, "No LastActiveSlotId")
	self.ActiveTransferableEphemeralKey =
		assert(options.ActiveTransferableEphemeralKey, "No ActiveTransferableEphemeralKey")
	self.MaxSlotCount = assert(options.MaxSlotCount, "No MaxSlotCount")

	self._sharedSaveSlotDataStoreService = assert(options.SharedDataStoreService, "No SharedDataStoreService")
	self._promisePreSelect = options.PromisePreSelect
	self._userId = options.UserId
	self._userName = options.UserName

	self._slotContainer = self._maid:Add(Instance.new("Folder"))
	self._slotContainer.Name = SaveSlotConstants.METADATA_CONTAINER_NAME
	self._slotContainer.Archivable = false

	-- Where the slot roster replicates from. Nothing here knows about players, so the owner mounts it:
	-- the binder mounts the bound player, and offline tooling mounts nothing and the roster stays
	-- unparented, replicating to no one.
	self.SlotContainerParent = self._maid:Add(ValueObject.new(nil))
	self._maid:GiveTask(self.SlotContainerParent:Observe():Subscribe(function(parent: Instance?)
		self._slotContainer.Parent = parent
	end))

	self._slotMap = {}
	self._ephemeralStores = {}
	self._transferableEphemeralKeys = {}
	self._codeGenerator = SaveSlotCodeUtils.generateDefaultCode

	self._loadPromise = self._maid:GivePromise(self:_promiseLoadSlots(promiseDataStore))

	if options.TrackPlaytime ~= false then
		self:_setupPlaytimeTracking()
	end

	return self
end

--[=[
	Returns the folder holding the slot's replicated metadata, or nil when there is no such slot.
	The folder is owned by this object; do not parent or destroy it.

	@param slotId SlotId?
	@return Folder?
]=]
function HasSaveSlotsDataStore.GetSlotFolder(self: HasSaveSlotsDataStore, slotId: SaveSlotData.SlotId?): Folder?
	if slotId == nil then
		return nil
	end
	return self._slotMap[slotId]
end

--[=[
	Returns the active slot's id, or nil when nothing is selected.

	@return SlotId?
]=]
function HasSaveSlotsDataStore.GetActiveSlotId(self: HasSaveSlotsDataStore): SaveSlotData.SlotId?
	return self.ActiveSlotId.Value
end

--[=[
	Returns the slot the player is on, or would resume on: the active slot when one is selected, and
	the persisted "Continue" target otherwise. The synchronous twin of
	[HasSaveSlotsDataStore.PromiseLastActiveSlotId].

	This is the one to read when acting on "their current slot" without a live session. Freshly opened
	against a datastore, nothing is selected yet -- the stored pointer loads as the last-active slot,
	and [HasSaveSlotsDataStore.GetActiveSlotId] stays nil until something selects.

	@return SlotId?
]=]
function HasSaveSlotsDataStore.GetLastActiveSlotId(self: HasSaveSlotsDataStore): SaveSlotData.SlotId?
	return self.ActiveSlotId.Value or self._lastActiveSlotId
end

--[=[
	Returns whether the active slot is an ephemeral (session-only) one. False when nothing is active.

	@return boolean
]=]
function HasSaveSlotsDataStore.IsActiveSlotEphemeral(self: HasSaveSlotsDataStore): boolean
	return self:_isEphemeral(self.ActiveSlotId.Value)
end

--[=[
	Returns the slot's metadata, or nil when there is no such slot.

	@param slotId SlotId?
	@return SaveSlotMetadata?
]=]
function HasSaveSlotsDataStore.GetSlotMetadata(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId?
): SaveSlotData.SaveSlotMetadata?
	local slot = self:GetSlotFolder(slotId)
	if not slot then
		return nil
	end
	return SaveSlotData:Get(slot)
end

--[=[
	Returns the active slot's metadata, or nil when nothing is selected. Unlike
	[HasSaveSlotsDataStore.GetSlotList] this does see an ephemeral slot, which is the only way to read
	the metadata of a session in progress.

	@return SaveSlotMetadata?
]=]
function HasSaveSlotsDataStore.GetActiveSlotMetadata(self: HasSaveSlotsDataStore): SaveSlotData.SaveSlotMetadata?
	return self:GetSlotMetadata(self.ActiveSlotId.Value)
end

--[=[
	Returns the persisted slots, ordered by index. Ephemeral slots are excluded, matching
	[SaveSlotDataService.GetSlotList] -- read the active slot directly with
	[HasSaveSlotsDataStore.GetActiveSlotMetadata] to see one.

	Ordered because the underlying map is not: an unordered listing would shuffle between calls, and
	the tooling reading this prints it.

	@return { SaveSlotMetadata }
]=]
function HasSaveSlotsDataStore.GetSlotList(self: HasSaveSlotsDataStore): { SaveSlotData.SaveSlotMetadata }
	local slotList = {}

	for slotId, slot in self._slotMap do
		if not self:_isEphemeral(slotId) then
			table.insert(slotList, SaveSlotData:Get(slot))
		end
	end

	table.sort(slotList, function(a, b)
		return a.SlotIndex < b.SlotIndex
	end)

	return slotList
end

--[=[
	Returns the id of the persisted slot at the given index, or nil when there is none. Ephemeral
	slots are never addressable by index.

	@param slotIndex number
	@return SlotId?
]=]
function HasSaveSlotsDataStore.GetSlotIdFromIndex(self: HasSaveSlotsDataStore, slotIndex: number): SaveSlotData.SlotId?
	for slotId, slot in self._slotMap do
		if not self:_isEphemeral(slotId) and slotIndex == SaveSlotData.SlotIndex:Get(slot) then
			return slotId
		end
	end
	return nil
end

--[=[
	Returns the [DataStoreStage] backing the slot's saved data. For the default slot this is the
	player's root store; for an ephemeral slot it is an in-memory store.

	@param slotId SlotId
	@return DataStoreStage
]=]
function HasSaveSlotsDataStore.GetSlotStore(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId
): DataStoreStage.DataStoreStage
	return self:_getSlotStore(slotId)
end

--[=[
	Observes the [DataStoreStage] for the active slot as a [Brio]
]=]
function HasSaveSlotsDataStore.ObserveActiveSlotStoreBrio(self: HasSaveSlotsDataStore): Observable.Observable<
	Brio.Brio<DataStoreStage.DataStoreStage>
>
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
function HasSaveSlotsDataStore.PromiseActiveSlotStore(
	self: HasSaveSlotsDataStore
): Promise.Promise<DataStoreStage.DataStoreStage?>
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
function HasSaveSlotsDataStore.PromiseSlotsLoaded(self: HasSaveSlotsDataStore): Promise.Promise<any>
	return self._loadPromise
end

--[=[
	Returns whether the slot with the given ID exists
]=]
function HasSaveSlotsDataStore.PromiseHasSlot(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId?
): Promise.Promise<boolean>
	return (self._loadPromise :: any):Then(function()
		return slotId and ((self._slotMap[slotId] :: Folder?) ~= nil)
	end)
end

-- Runs the injected pre-select veto, if there is one. A caller that registered none allows every
-- selection, which is what offline tooling and a binder without SaveSlotService both want.
function HasSaveSlotsDataStore._promiseRunPreSelect(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId
): Promise.Promise<boolean>
	local promisePreSelect = self._promisePreSelect
	if not promisePreSelect then
		return (Promise :: any).resolved(true)
	end

	return promisePreSelect(slotId)
end

--[=[
	Selects the slot with the given ID
]=]
function HasSaveSlotsDataStore.PromiseSelectSlot(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId
): Promise.Promise<any>
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

		local function promiseSetSlot()
			return self._maid:GivePromise(self:_promiseRunPreSelect(slotId)):Then(function(allowed: boolean)
				if not allowed then
					return (Promise :: any).rejected(`Slot \{{slotId}\} refused by a pre-select callback`)
				end

				return setSlot()
			end)
		end

		-- Initialize or save and switch
		if self.ActiveSlotId.Value == nil then
			return promiseSetSlot()
		end

		-- Leaving an ephemeral slot has nothing to persist, so switch without a datastore flush (the flush
		-- exists to save the outgoing slot's progress, and an ephemeral slot has none).
		if self:_isEphemeral(self.ActiveSlotId.Value) then
			return promiseSetSlot()
		end

		return self._maid:GivePromise(self._dataStore:Save()):Then(promiseSetSlot)
	end)
end

--[=[
	Clears the active slot selection, returning the player to a no-slot state --
	the counterpart to [HasSaveSlotsDataStore.PromiseSelectSlot], backing a "back to menu"
	affordance. The active slot's progress is flushed first (mirroring the save
	PromiseSelectSlot runs when switching away), and the last-active slot is
	remembered, so [HasSaveSlotsDataStore.PromiseSelectLastSaveSlot] can resume it later.
	A no-op when no slot is active.
]=]
function HasSaveSlotsDataStore.PromiseDeselectSlot(self: HasSaveSlotsDataStore): Promise.Promise<()>
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
function HasSaveSlotsDataStore.PromiseCreateSlot(
	self: HasSaveSlotsDataStore,
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
			TimePlayed = metadata and metadata.TimePlayed,
		}

		self:_buildSlot(slotId, data, true)
		return slotId
	end)
end

--[=[
	Exports a slot's saved data into a plain, serializable [SaveSlotExportUtils.SaveSlotExport].
	Rejects the main/default slot by default: its store is the player's shared root datastore, so
	exporting it would leak the SaveSlots system data and universe-scoped global data living
	alongside it. Only isolated non-main slot substores are exportable.

	`allowMainSlot` opts out of that refusal for trusted admin tooling (see [SaveSlotCmdrService]).
	The SaveSlots system data is always stripped from the result, so the export never carries the
	slot roster or the other slots' saved data. Universe-scoped global data sharing the root store
	is indistinguishable from the main slot's own data and is still carried, which is why this is
	not exposed through [SaveSlotService].

	@param slotId SlotId
	@param allowMainSlot boolean? -- defaults to false
	@return Promise<SaveSlotExportUtils.SaveSlotExport>
]=]
function HasSaveSlotsDataStore.PromiseExportSlot(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId,
	allowMainSlot: boolean?
): Promise.Promise<SaveSlotExportUtils.SaveSlotExport>
	return (self._loadPromise :: any):Then(function()
		local slot = self._slotMap[slotId]
		if not slot then
			return (Promise :: any).rejected(`Slot \{{slotId}\} not found`)
		end

		local isMainSlot = SaveSlotExportUtils.isMainSlotIndex(SaveSlotData.SlotIndex:Get(slot))
		if isMainSlot and not allowMainSlot then
			return (Promise :: any).rejected("Cannot export the main slot")
		end

		-- As in PromiseDuplicateSlot: bring the live session's accrued time into TimePlayed before it is
		-- read, so an export of the active slot carries its playtime up to this moment.
		self:_flushPlaytime()

		local metadata = SaveSlotData:Get(slot)
		return self:_getSlotStore(slotId):LoadAll({}):Then(function(sourceData)
			local data = if type(sourceData) == "table" then table.clone(sourceData) else {}

			if isMainSlot then
				-- The main slot's store is the player's shared root, so LoadAll pulls the SaveSlots system
				-- data with it -- the slot roster and every non-main slot's saved data. Drop it so the
				-- export is only this slot, and so importing it can't nest a whole roster inside a slot
				-- (mirrors PromiseDuplicateSlot, which strips the same key for the same reason).
				data[SaveSlotConstants.SYSTEM_STORE_KEY] = nil
			end

			return SaveSlotExportUtils.create(data, metadata.SlotName, metadata.Summary, metadata.TimePlayed)
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
function HasSaveSlotsDataStore.PromiseImportSlot(
	self: HasSaveSlotsDataStore,
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
			-- Absent on exports taken before playtime was carried; those import as before, with no playtime.
			TimePlayed = export.timePlayed,
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
	Exports a non-main slot (see [HasSaveSlotsDataStore.PromiseExportSlot]) and writes it to the shared
	save slot store under the given key.

	@param slotId SlotId
	@param key string
	@param allowMainSlot boolean? -- defaults to false, see [HasSaveSlotsDataStore.PromiseExportSlot]
	@return Promise<boolean>
]=]
function HasSaveSlotsDataStore.PromiseSaveSlotToSharedDataStore(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId,
	key: string,
	allowMainSlot: boolean?
): Promise.Promise<boolean>
	return self:PromiseExportSlot(slotId, allowMainSlot):Then(function(export)
		return self._sharedSaveSlotDataStoreService:PromiseWrite(key, export)
	end)
end

--[=[
	Reads an export from the shared save slot store and imports it into a fresh non-main slot (see
	[HasSaveSlotsDataStore.PromiseImportSlot]). Rejects when no export is stored under the key.

	@param key string
	@return Promise<SlotId>
]=]
function HasSaveSlotsDataStore.PromiseImportSlotFromSharedDataStore(
	self: HasSaveSlotsDataStore,
	key: string
): Promise.Promise<SaveSlotData.SlotId>
	-- Maid-owned like the other shared-store reads: this one is not even gated behind _loadPromise, so
	-- nothing upstream rejects it when the player leaves mid-read.
	return self._maid:GivePromise(self._sharedSaveSlotDataStoreService:PromiseRead(key)):Then(function(export)
		if not self.Destroy then
			return (Promise :: any).rejected() -- Destroyed. Empty, so it stays out of the logs
		end

		if export == nil then
			return (Promise :: any).rejected(`No save slot stored under \{{key}\}`)
		end
		return self:PromiseImportSlot(export)
	end)
end

--[=[
	Loads the export stored under the given shared-store key into a fresh ephemeral slot and selects it,
	remembering the key so a teleport can carry the slot forward (see the transferable-ephemeral teleport
	provider in [SaveSlotService]). Like every ephemeral slot it is never persisted, stays out of the slot
	list, and is torn down on deselect. Rejects when no valid export is stored under the key.

	@param key string
	@return Promise<SlotId>
]=]
function HasSaveSlotsDataStore.PromiseSelectTransferableEphemeralSlot(
	self: HasSaveSlotsDataStore,
	key: string
): Promise.Promise<SaveSlotData.SlotId>
	return (self._loadPromise :: any):Then(function()
		-- Maid-owned for the same reason as _promiseLoadSlots: this read runs on the join path (a teleport
		-- arriving with an ephemeral key) and outlives a leave, and its continuation builds a slot.
		return self._maid:GivePromise(self._sharedSaveSlotDataStoreService:PromiseRead(key)):Then(function(export)
			if not self.Destroy then
				-- Destroyed. Rejecting keeps the Promise<SlotId> contract honest -- a nil fulfilment reads as
				-- "imported, no slot" to a caller like SaveSlotCmdrService. Empty, so it stays out of the logs.
				return (Promise :: any).rejected()
			end

			if export == nil then
				return (Promise :: any).rejected(`No save slot stored under \{{key}\}`)
			end
			if not SaveSlotExportUtils.isSaveSlotExport(export) then
				return (Promise :: any).rejected("Bad save slot export in shared store")
			end

			local slotId = HttpService:GenerateGUID(false)
			self:_buildSlot(slotId, {
				SlotId = slotId,
				SlotIndex = SaveSlotConstants.EPHEMERAL_SLOT_INDEX,
				SlotName = export.slotName or "Transfer",
				CreatedTime = os.time(),
				Summary = export.summary,
			}, true, true)

			-- Seed the in-memory store before selecting so a consumer of ObserveActiveSlotStoreBrio never
			-- observes an empty active slot; then remember the key this slot transfers under.
			self:_getSlotStore(slotId):Overwrite(export.data)
			self._transferableEphemeralKeys[slotId] = key

			return self:PromiseSelectSlot(slotId):Then(function()
				return slotId
			end)
		end)
	end)
end

--[=[
	Builds this player's teleport slice for a transferable ephemeral slot: re-saves the active slot's
	*current live* data to the shared store under its key and returns a slice carrying that key. Resolves
	nil when the active slot is not a transferable ephemeral slot. A failed re-save degrades to nil so a
	teleport is never blocked (the destination then re-loads the last saved state). Asynchronous -- it is
	consumed through [TeleportDataService.PromiseBuildTeleportData].

	@return Promise<{ [string]: any }?>
]=]
function HasSaveSlotsDataStore.PromiseBuildEphemeralTransferSlice(
	self: HasSaveSlotsDataStore
): Promise.Promise<{ [string]: any }?>
	return (self._loadPromise :: any):Then(function(): any
		local slotId = self.ActiveSlotId.Value
		if not slotId then
			return nil
		end
		local storeKey = self._transferableEphemeralKeys[slotId]
		if not storeKey then
			return nil
		end

		return self:PromiseExportSlot(slotId)
			:Then(function(export)
				return self._sharedSaveSlotDataStoreService:PromiseWrite(storeKey, export)
			end)
			:Then(function()
				return { [SaveSlotConstants.TELEPORT_DATA_EPHEMERAL_KEY] = storeKey }
			end)
			:Catch(function()
				return nil
			end)
	end)
end

--[=[
	Overrides the share-code generator for this player's exports (see [SaveSlotCodeUtils.CodeGenerator]).
	Games inject a custom format; the default is [SaveSlotCodeUtils.generateDefaultCode]. Usually set
	game-wide via [SaveSlotService.SetCodeGenerator] rather than per player.

	@param generator CodeGenerator
]=]
function HasSaveSlotsDataStore.SetCodeGenerator(
	self: HasSaveSlotsDataStore,
	generator: SaveSlotCodeUtils.CodeGenerator
): ()
	assert(type(generator) == "function", "Bad generator")
	self._codeGenerator = generator
end

-- Builds a code for a slot from the configured generator, taking the owner's identity from the
-- injected options (absent offline, where there may be no name to resolve) and the slot's
-- name/index from its metadata.
function HasSaveSlotsDataStore._generateCode(self: HasSaveSlotsDataStore, slotId: SaveSlotData.SlotId): string
	local slot = self._slotMap[slotId]
	local metadata = if slot then SaveSlotData:Get(slot) else nil

	return self._codeGenerator({
		userId = self._userId,
		userName = self._userName,
		slotName = metadata and metadata.SlotName,
		slotIndex = metadata and metadata.SlotIndex,
	})
end

--[=[
	Exports a slot to the shared store under a fresh generated code and resolves to that code. The code
	is a shareable handle other sessions load with
	[HasSaveSlotsDataStore.PromiseImportEphemeralSaveSlotFromCode]. Defaults to the active slot. Refuses
	the main slot unless `allowMainSlot` is set (see [HasSaveSlotsDataStore.PromiseExportSlot]). The code
	format comes from the configured generator (see [HasSaveSlotsDataStore.SetCodeGenerator]).

	@param slotId SlotId? -- defaults to the active slot
	@param allowMainSlot boolean? -- defaults to false, see [HasSaveSlotsDataStore.PromiseExportSlot]
	@return Promise<string>
]=]
function HasSaveSlotsDataStore.PromiseExportSaveSlotToCode(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId?,
	allowMainSlot: boolean?
): Promise.Promise<string>
	return (self._loadPromise :: any):Then(function()
		local targetSlotId = slotId or self.ActiveSlotId.Value
		if not targetSlotId then
			return (Promise :: any).rejected("No slot to export")
		end

		local code = self:_generateCode(targetSlotId)
		return self:PromiseSaveSlotToSharedDataStore(targetSlotId, code, allowMainSlot):Then(function()
			return code
		end)
	end)
end

--[=[
	Loads the slot stored under the given code into a fresh transferable ephemeral slot and selects it
	(see [HasSaveSlotsDataStore.PromiseSelectTransferableEphemeralSlot]). Resolves to the new slot id.

	@param code string
	@return Promise<SlotId>
]=]
function HasSaveSlotsDataStore.PromiseImportEphemeralSaveSlotFromCode(
	self: HasSaveSlotsDataStore,
	code: string
): Promise.Promise<SaveSlotData.SlotId>
	return self:PromiseSelectTransferableEphemeralSlot(code)
end

--[=[
	Exports a slot as a raw JSON string (no shared store), for direct inspection or attaching to a bug
	report. Defaults to the active slot. Refuses the main slot unless `allowMainSlot` is set (see
	[HasSaveSlotsDataStore.PromiseExportSlot]).

	@param slotId SlotId? -- defaults to the active slot
	@param allowMainSlot boolean? -- defaults to false, see [HasSaveSlotsDataStore.PromiseExportSlot]
	@return Promise<string>
]=]
function HasSaveSlotsDataStore.PromiseExportSaveSlotToJson(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId?,
	allowMainSlot: boolean?
): Promise.Promise<string>
	return (self._loadPromise :: any):Then(function()
		local targetSlotId = slotId or self.ActiveSlotId.Value
		if not targetSlotId then
			return (Promise :: any).rejected("No slot to export")
		end

		return self:PromiseExportSlot(targetSlotId, allowMainSlot):Then(function(export)
			return HttpService:JSONEncode(export)
		end)
	end)
end

--[=[
	Duplicates the slot with the given ID into a new slot at the lowest free index,
	copying its saved data and accrued playtime. Resolves to the new slot's id. The copy is not
	selected, its timestamps and session counters start fresh, and its name is suffixed with
	" (Copy)". Rejects when the source slot is missing or every index is in use.

	An ephemeral slot may be duplicated: the copy is a real, persisted slot seeded with the ephemeral
	slot's live in-memory data, which is how a throwaway session is turned into a save. It keeps the
	source's name unsuffixed (the copy is the first real slot for that session, not a second copy of an
	existing save) and, like any duplicate, is not selected -- see
	[HasSaveSlotsDataStore.PromisePersistEphemeralSlot] for the version that continues play on the new slot.
]=]
function HasSaveSlotsDataStore.PromiseDuplicateSlot(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId
): Promise.Promise<SaveSlotData.SlotId>
	return (self._loadPromise :: any):Then(function()
		local sourceSlot = self._slotMap[slotId]
		if not sourceSlot then
			return (Promise :: any).rejected(`Slot \{{slotId}\} not found`)
		end

		local sourceIsEphemeral = self:_isEphemeral(slotId)

		-- The source is usually the live active slot, whose current session has not landed in TimePlayed
		-- yet; fold it in first so the copy carries the playtime the player is actually looking at.
		self:_flushPlaytime()

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

			return self
				:PromiseCreateSlot(freeIndex, {
					SlotName = if sourceIsEphemeral
						then sourceMetadata.SlotName
						else `{sourceMetadata.SlotName} (Copy)`,
					Summary = sourceMetadata.Summary,
					-- Playtime describes the progress being copied, not the slot it happens to live in, so
					-- it travels with that progress rather than resetting the copy to a never-played slot.
					TimePlayed = sourceMetadata.TimePlayed,
				})
				:Then(function(newSlotId: SaveSlotData.SlotId)
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
	Turns an ephemeral slot into a real save: duplicates it into a fresh persisted slot at the lowest free
	index (see [HasSaveSlotsDataStore.PromiseDuplicateSlot]) and selects that slot, so play continues on
	data that is now being written. Defaults to the active slot, which in practice is the only ephemeral
	slot there is -- one stops existing the moment it stops being active. Resolves to the new slot's id.

	The copy is taken from the ephemeral slot's live in-memory data at the moment this runs, and selecting
	the new slot retires the ephemeral one, so anything written to the old store between the copy and the
	selection is dropped. Rejects when no slot is active, the slot is missing, the slot is not ephemeral,
	or every index is in use.

	@param slotId SlotId? -- defaults to the active slot
	@return Promise<SlotId>
]=]
function HasSaveSlotsDataStore.PromisePersistEphemeralSlot(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId?
): Promise.Promise<SaveSlotData.SlotId>
	return (self._loadPromise :: any):Then(function()
		local targetSlotId = slotId or self.ActiveSlotId.Value
		if not targetSlotId then
			return (Promise :: any).rejected("No slot to persist")
		end

		if not self._slotMap[targetSlotId] then
			return (Promise :: any).rejected(`Slot \{{targetSlotId}\} not found`)
		end

		if not self:_isEphemeral(targetSlotId) then
			return (Promise :: any).rejected(`Slot \{{targetSlotId}\} is already persisted`)
		end

		return self:PromiseDuplicateSlot(targetSlotId):Then(function(newSlotId: SaveSlotData.SlotId)
			return self:PromiseSelectSlot(newSlotId):Then(function()
				return newSlotId
			end)
		end)
	end)
end

--[=[
	Deletes the slot with the given ID. Deleting an ephemeral slot ends that session -- it is deselected
	and retired along with its in-memory store -- rather than being refused for being the active slot.
]=]
function HasSaveSlotsDataStore.PromiseDeleteSlot(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId
): Promise.Promise<any>
	return (self._loadPromise :: any):Then(function()
		-- An ephemeral slot only exists while it is active, so deleting one is retiring it. Nothing was
		-- ever persisted, so there is no stored data to wipe afterwards -- hence the early return.
		if self:_isEphemeral(slotId) then
			if slotId == self.ActiveSlotId.Value then
				return self:PromiseDeselectSlot()
			end
			self:_destroyEphemeralSlot(slotId)
			return (Promise :: any).resolved()
		end

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
function HasSaveSlotsDataStore.PromiseDeleteAllSlots(self: HasSaveSlotsDataStore): Promise.Promise<any>
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
	slot: everything bound to [HasSaveSlotsDataStore.ObserveActiveSlotStoreBrio] tears down as the
	selection clears and rebuilds against the empty store on reselect, so consumers reset
	reactively without wiping their own state. A non-active slot is left unselected, and its
	"Continue" pointer (when it was the last-active slot) is carried across to the fresh id so
	the reset slot stays resumable. Rejects when the slot is missing.
]=]
function HasSaveSlotsDataStore.PromiseResetSlot(
	self: HasSaveSlotsDataStore,
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
	Resets the active slot to a fresh empty one -- see [HasSaveSlotsDataStore.PromiseResetSlot]. The slot
	keeps its index and name; its saved data and metadata (timestamps) start fresh, and the fresh
	slot stays selected. Resolves to the new slot id, or nil when no slot is active.
]=]
function HasSaveSlotsDataStore.PromiseResetActiveSlot(
	self: HasSaveSlotsDataStore
): Promise.Promise<SaveSlotData.SlotId?>
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
function HasSaveSlotsDataStore.PromiseSetSlotMetadata(
	self: HasSaveSlotsDataStore,
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
function HasSaveSlotsDataStore.PromiseGetSlotMetadata(
	self: HasSaveSlotsDataStore,
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
function HasSaveSlotsDataStore.PromiseSlotIdFromIndex(
	self: HasSaveSlotsDataStore,
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
function HasSaveSlotsDataStore.PromiseLastActiveSlotId(
	self: HasSaveSlotsDataStore
): Promise.Promise<SaveSlotData.SlotId?>
	return (self._loadPromise :: any):Then(function()
		return self.ActiveSlotId.Value or self._lastActiveSlotId
	end)
end

--[=[
	Selects the player's last active slot if one still exists, resolving to the
	selected slot id -- or nil when there is no slot to continue on. Backs a
	"Continue" affordance that every save-slot consumer tends to need.
]=]
function HasSaveSlotsDataStore.PromiseSelectLastSaveSlot(
	self: HasSaveSlotsDataStore
): Promise.Promise<SaveSlotData.SlotId?>
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
function HasSaveSlotsDataStore.PromiseSelectNewSaveSlot(
	self: HasSaveSlotsDataStore
): Promise.Promise<SaveSlotData.SlotId?>
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
	active exactly like a real one -- it drives [HasSaveSlotsDataStore.ObserveActiveSlotStoreBrio],
	summaries, and playtime the same way, and its metadata replicates to the client like any other slot's,
	so UI can render the active session's name and summary -- but it is never persisted: no metadata is
	written, its data store is in-memory, and it is torn down the moment it stops being the active slot. It
	is also excluded from the save list ([SaveSlotDataService.GetSlotList] /
	[SaveSlotDataService.ObserveSlotList]), so it never shows up as something the player can return to.
	Selecting it never disturbs the persisted active-slot pointer or the "Continue" target, so the real slot
	the player came from resumes untouched afterward. Backs a throwaway session (e.g. exploring a lobby)
	that must leave no trace on save data.

	@param metadata SaveSlotCreateMetadata? -- optional SlotName/Summary for the in-memory slot
	@return Promise<SlotId>
]=]
function HasSaveSlotsDataStore.PromiseSelectEphemeralSlot(
	self: HasSaveSlotsDataStore,
	metadata: SaveSlotCreateMetadata?
): Promise.Promise<SaveSlotData.SlotId>
	return (self._loadPromise :: any):Then(function()
		local slotId = HttpService:GenerateGUID(false)
		local data = {
			SlotId = slotId,
			SlotIndex = SaveSlotConstants.EPHEMERAL_SLOT_INDEX,
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

-- Maid-owning every hop is what makes this safe, for the same reason as the selection chain in
-- SaveSlotService: a session-locked or retrying read settles long after the player left, and Promise has no
-- cancellation, so owning only the outermost promise detaches nothing upstream. Calling into this destroyed
-- (metatable-stripped) object -- or into its destroyed stores -- throws, and because a datastore load
-- resolves inside its UpdateAsync transform, that throw surfaces as a "Transform function error" and takes
-- the transform's write down with it. The liveness checks cover a settle that lands mid-teardown, before
-- this promise's own maid task was reached. See SaveSlotLateSettle.spec.
function HasSaveSlotsDataStore._promiseLoadSlots(
	self: HasSaveSlotsDataStore,
	promiseDataStore: Promise.Promise<any>
): Promise.Promise<{}>
	return self._maid:GivePromise(promiseDataStore):Then(function(dataStore)
		if not self.Destroy then
			return nil -- Destroyed
		end

		self._dataStore = dataStore
		self._systemStore = dataStore:GetSubStore(SaveSlotConstants.SYSTEM_STORE_KEY)
		self._metadataStore = self._systemStore:GetSubStore(SaveSlotConstants.METADATA_STORE_KEY)

		return self._maid:GivePromise(self._metadataStore:LoadAll({})):Then(function(metadata)
			if not self.Destroy then
				return nil -- Destroyed
			end

			for slotId, data in metadata do
				self:_buildSlot(slotId, data)
			end

			return self._maid
				:GivePromise(self._systemStore:Load("activeSlotId"))
				:Then(function(activeId: SaveSlotData.SlotId?)
					if not self.Destroy then
						return nil -- Destroyed
					end

					self._lastActiveSlotId = activeId
					self.LastActiveSlotId.Value = activeId

					-- The persisted active-slot pointer and the replicated "Continue" target only ever track real
					-- slots. This replaces StoreOnValueChange so an ephemeral selection is invisible to both:
					-- entering one leaves them pinned to the real slot, and the ephemeral slot is torn down the
					-- moment it stops being active. We track the id we are leaving to know which of those to do.
					local previousActiveSlotId: SaveSlotData.SlotId? = activeId

					self._maid:GiveTask(self.ActiveSlotId.Changed:Connect(function()
						local active = self.ActiveSlotId.Value

						-- Replicate the active transferable-ephemeral slot's shared-store key (nil otherwise) so a
						-- client-initiated teleport can carry it forward (SaveSlotServiceClient's provider reads this).
						self.ActiveTransferableEphemeralKey.Value = if active
							then self._transferableEphemeralKeys[active]
							else nil

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

					-- Matches the liveness-guard returns above, which make this callback's inferred return
					-- type nil; falling off the end instead returns no values at all.
					return nil
				end)
		end)
	end)
end

function HasSaveSlotsDataStore._getSlotStore(
	self: HasSaveSlotsDataStore,
	slotId: SaveSlotData.SlotId
): DataStoreStage.DataStoreStage
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

function HasSaveSlotsDataStore._buildSlot(
	self: HasSaveSlotsDataStore,
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
		-- Ephemeral: seed the metadata in memory with no write-back wiring, and back the slot with an in-memory
		-- store. The folder still joins the replicated container so the client can read the active slot's
		-- metadata (name, summary, playtime) the same way it reads a real slot's -- what makes the slot
		-- ephemeral is that nothing is persisted, not that it is invisible. The IsEphemeral attribute is what
		-- keeps it out of the save list; SaveSlotDataService's list reads filter on it.
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

		-- Parent last, so the folder replicates carrying IsEphemeral -- a client that saw it land without the
		-- flag would briefly list a throwaway slot as a save.
		slot.Parent = self._slotContainer

		self._slotMap[slotId] = slot
		maid:GiveTask(function()
			self._slotMap[slotId] = nil
			self._ephemeralStores[slotId] = nil
			self._transferableEphemeralKeys[slotId] = nil
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
function HasSaveSlotsDataStore._isEphemeral(self: HasSaveSlotsDataStore, slotId: SaveSlotData.SlotId?): boolean
	if slotId == nil then
		return false
	end
	local slot = self._slotMap[slotId] :: Folder?
	return slot ~= nil and SaveSlotData.IsEphemeral:Get(slot) == true
end

-- Tears down the ephemeral slot's maid (folder, in-memory store, and every map entry via the teardown task
-- registered in _buildSlot). Idempotent -- clearing an already-cleared maid key is a no-op.
function HasSaveSlotsDataStore._destroyEphemeralSlot(self: HasSaveSlotsDataStore, slotId: SaveSlotData.SlotId): ()
	self._maid[slotId] = nil
end

--[=[
	Accrues per-slot playtime automatically. A "session" spans the time a slot is the active slot:
	selecting a slot begins one (bumping PlayCount), and deselecting, switching, or unbinding ends
	it. Elapsed wall time is folded into the slot's TimePlayed from a datastore saving callback, so
	it persists on exactly the cadence the data is written -- always fresh at save time, with no
	separate timer -- and again at each session boundary.

	Skipped entirely when the owner opts out (`TrackPlaytime = false`), which is what offline admin
	tooling wants: editing a slot from a console is not someone playing it, and no session is ever
	begun, so `_flushPlaytime` stays a no-op for the object's whole life.
]=]
function HasSaveSlotsDataStore._setupPlaytimeTracking(self: HasSaveSlotsDataStore): ()
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

function HasSaveSlotsDataStore._beginPlaySession(self: HasSaveSlotsDataStore, slotId: SaveSlotData.SlotId): ()
	local now = os.time()
	self._playSessionSlotId = slotId
	self._playSessionStart = now
	self._playSessionLastFlush = now

	local slot = self._slotMap[slotId]
	if slot then
		SaveSlotData.PlayCount:Set(slot, (SaveSlotData.PlayCount:Get(slot) or 0) + 1)
	end
end

function HasSaveSlotsDataStore._flushPlaytime(self: HasSaveSlotsDataStore): ()
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

function HasSaveSlotsDataStore._endPlaySession(self: HasSaveSlotsDataStore): ()
	if self._playSessionSlotId == nil then
		return
	end

	self:_flushPlaytime()
	self._playSessionSlotId = nil
	self._playSessionStart = nil
	self._playSessionLastFlush = nil
end

return HasSaveSlotsDataStore
