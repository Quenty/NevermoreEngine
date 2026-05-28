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
		},
		{} :: typeof({ __index = HasSaveSlots })
	))
	& HasSaveSlotsBase.HasSaveSlotsBase

function HasSaveSlots.new(player: Player, serviceBag: ServiceBag.ServiceBag): HasSaveSlots
	local self: HasSaveSlots = setmetatable(HasSaveSlotsBase.new(player, serviceBag) :: any, HasSaveSlots)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._playerDataStoreService = self._serviceBag:GetService(PlayerDataStoreService)

	self._slotContainer = self._maid:Add(Instance.new("Folder"))
	self._slotContainer.Name = SaveSlotConstants.METADATA_CONTAINER_NAME
	self._slotContainer.Archivable = false
	self._slotContainer.Parent = self._obj

	self._slotMap = {}

	self._summaryProvider = self._maid:Add(ValueObject.new(nil))

	self._loadPromise = self._maid:GivePromise(self:_promiseLoadSlots())

	self._remoting = self._maid:Add(Remoting.Server.new(self._obj, "HasSaveSlots"))

	self:_setupSummary()
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
		print(self.ActiveSlotId.Value)
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

		-- Wipe default slot
		local slotIndex = SaveSlotData.SlotIndex:Get(slot)

		if slotIndex == SaveSlotConstants.DEFAULT_SLOT_INDEX then
			return self._dataStore:PromiseKeyList():Then(function(keys)
				for _, key in keys do
					if key ~= SaveSlotConstants.INTERNAL_STORE_KEY then
						self._dataStore:Delete(key)
					end
				end
				self._metadataStore:Delete(slotId)
			end)
		end

		-- Or delete slot from substore
		self._systemStore:GetSubStore(SaveSlotConstants.SLOT_STORE_KEY):Delete(slotId)
		self._metadataStore:Delete(slotId)
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
	Sets the summary provider
]=]
function HasSaveSlots.SetSummaryProvider(self: HasSaveSlots, provider: SaveSlotSummaryProvider?): ()
	self._summaryProvider.Value = provider
end

function HasSaveSlots._promiseLoadSlots(self: HasSaveSlots): Promise.Promise<{}>
	return self._playerDataStoreService:PromiseDataStore(self._obj):Then(function(dataStore)
		self._dataStore = dataStore
		self._systemStore = dataStore:GetSubStore(SaveSlotConstants.INTERNAL_STORE_KEY)
		self._metadataStore = self._systemStore:GetSubStore(SaveSlotConstants.METADATA_STORE_KEY)

		return self._metadataStore:LoadAll({}):Then(function(metadata)
			for slotId, data in metadata do
				self:_buildSlot(slotId, data)
			end

			return self._systemStore:Load("activeSlotId"):Then(function(activeId: SaveSlotData.SlotId?)
				self._lastActiveSlotId = activeId
				self._maid:GiveTask(self._systemStore:StoreOnValueChange("activeSlotId", self.ActiveSlotId))
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
	for _, key in { "SlotName", "CreatedTime", "LastPlayedTime", "Summary" } do
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
