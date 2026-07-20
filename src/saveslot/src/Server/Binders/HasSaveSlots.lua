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
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerBinder = require("PlayerBinder")
local PlayerDataStoreService = require("PlayerDataStoreService")
local Promise = require("Promise")
local Remoting = require("Remoting")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local ServiceBag = require("ServiceBag")
local TeleportDataService = require("TeleportDataService")
local ValueObject = require("ValueObject")

export type SaveSlotSummaryProvider = (Player, any) -> Observable.Observable<string>

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
			_loadPromise: Promise.Promise<{}>,
			_remoting: any,
			_dataStore: any,
			_systemStore: any,
			_metadataStore: any,
			_summaryProvider: ValueObject.ValueObject<SaveSlotSummaryProvider?>,
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

	self._summaryProvider = self._maid:Add(ValueObject.new(nil))

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
	metadata: SaveSlotData.SaveSlotMetadata?
): Promise.Promise<SaveSlotData.SlotId>
	return (self._loadPromise :: any):Then(function()
		if (slotIndex < 1) or (slotIndex > self.MaxSlotCount.Value) then
			return (Promise :: any).rejected(`Index must be in range [1, {self.MaxSlotCount.Value}]`)
		end

		for _, slot in self._slotMap do
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
		for _, slot in self._slotMap do
			usedIndices[SaveSlotData.SlotIndex:Get(slot)] = true
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
	Sets the summary provider
]=]
function HasSaveSlots.SetSummaryProvider(self: HasSaveSlots, provider: SaveSlotSummaryProvider?): ()
	self._summaryProvider.Value = provider
end

-- Server realm hook for HasSaveSlotsBase: the incoming slot id is whatever the player teleported in
-- with, read from their join data via TeleportDataService.
function HasSaveSlots._getIncomingSlotId(self: HasSaveSlots): SaveSlotData.SlotId?
	local slotId = self._teleportDataService:GetArrivedValue(self._obj, SaveSlotConstants.TELEPORT_DATA_SLOT_KEY)
	if type(slotId) == "string" then
		return slotId
	end
	return nil
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
				self._maid:GiveTask(self._systemStore:StoreOnValueChange("activeSlotId", self.ActiveSlotId))

				-- Keep the replicated last-active in sync as the player selects slots this session
				self._maid:GiveTask(self.ActiveSlotId.Changed:Connect(function()
					local active = self.ActiveSlotId.Value
					if active ~= nil then
						self._lastActiveSlotId = active
						self.LastActiveSlotId.Value = active
					end
				end))
			end)
		end)
	end)
end

function HasSaveSlots._getSlotStore(self: HasSaveSlots, slotId: SaveSlotData.SlotId): DataStoreStage.DataStoreStage
	local slot = self._slotMap[slotId]
	if slot and (SaveSlotData.SlotIndex:Get(slot) == SaveSlotConstants.DEFAULT_SLOT_INDEX) then
		return self._dataStore
	end
	return self._systemStore:GetSubStore(SaveSlotConstants.SLOT_STORE_KEY):GetSubStore(slotId)
end

function HasSaveSlots._buildSlot(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId,
	data: SaveSlotData.SaveSlotMetadata,
	isNew: boolean?
): ()
	local maid = Maid.new()
	self._maid[slotId] = maid

	local slot = maid:Add(Instance.new("Folder"))
	slot.Name = slotId
	slot.Archivable = false

	local metadataStore = self._metadataStore:GetSubStore(slotId)

	local attributes = SaveSlotData:Create(slot)
	attributes.SlotId.Value = slotId
	attributes.SlotIndex.Value = data.SlotIndex

	-- Store immutable SlotIndex once on creation
	if isNew then
		metadataStore:Store("SlotIndex", data.SlotIndex)
	end

	-- Store mutable metadata on change
	for _, key in
		{ "SlotName", "CreatedTime", "LastPlayedTime", "Summary", "TimePlayed", "PlayCount", "LastSessionLength" }
	do
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

			maid:GiveTask(self._summaryProvider
				:Observe()
				:Pipe({
					Rx.switchMap(function(provider: SaveSlotSummaryProvider?)
						if not provider then
							return Rx.of("") :: any
						end

						local success, observable = pcall(provider, self._obj, slotStore)
						if not success then
							warn(`[HasSaveSlots] Summary provider errored: {observable}`)
							return Rx.of("") :: any
						end

						return observable
					end) :: any,
				})
				:Subscribe(function(summary: string)
					if type(summary) ~= "string" then
						warn(`[HasSaveSlots] Summary provider emitted non-string ({typeof(summary)})`)
						return
					end

					SaveSlotData.Summary:Set(activeSlot, summary)
				end))
		end)
	)
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
