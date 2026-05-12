--!strict
--[=[
	@class HasSaveSlots
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local HasSaveSlotsBase = require("HasSaveSlotsBase")
local HasSaveSlotsInterface = require("HasSaveSlotsInterface")
local Maid = require("Maid")
local PlayerBinder = require("PlayerBinder")
local PlayerDataStoreService = require("PlayerDataStoreService")
local Promise = require("Promise")
local Remoting = require("Remoting")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local ServiceBag = require("ServiceBag")

type SaveSlot = {
	folder: Folder,
	attributes: any,
	maid: Maid.Maid,
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
			_slotMap: { [number]: SaveSlot },
			_loadPromise: Promise.Promise<{}>,
			_remoting: any,
			_dataStore: any,
			_metadataStore: any,
			_summaryProvider: ((Player, any) -> string)?,
			_lastActiveSlotIndex: number?,
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

	self._loadPromise = self._maid:GivePromise(self:_promiseLoadSlots())

	self._remoting = self._maid:Add(Remoting.Server.new(self._obj, "HasSaveSlots"))

	self:_setupRemotes()

	self._maid:GiveTask(HasSaveSlotsInterface.Server:Implement(self._obj, self))

	return self
end

--[=[
	Promises that all slots have loaded
]=]
function HasSaveSlots.PromiseSlotsLoaded(self: HasSaveSlots): Promise.Promise<any>
	return self._loadPromise
end

--[=[
	Returns whether the slot at the given index exists
]=]
function HasSaveSlots.PromiseHasSlot(self: HasSaveSlots, slotIndex: number): Promise.Promise<boolean>
	return (self._loadPromise :: any):Then(function()
		return (self._slotMap[slotIndex] ~= nil)
	end)
end

--[=[
	Selects the slot at the given index
]=]
function HasSaveSlots.PromiseSelectSlot(self: HasSaveSlots, slotIndex: number): Promise.Promise<any>
	return (self._loadPromise :: any):Then(function()
		if slotIndex == self.ActiveSlotIndex.Value then
			return -- Already set
		end

		local slot = self._slotMap[slotIndex]
		if not slot then
			return (Promise :: any).rejected(`Slot {slotIndex} not found`)
		end

		local function setSlot()
			self.ActiveSlotIndex.Value = slotIndex
			slot.attributes.LastPlayedTime.Value = os.time()
		end

		-- Initialize or save and switch
		if self.ActiveSlotIndex.Value == nil then
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
): Promise.Promise<any>
	return (self._loadPromise :: any):Then(function()
		if self._slotMap[slotIndex] then
			return (Promise :: any).rejected(`Slot {slotIndex} already exists`)
		end

		if slotIndex > self.MaxSlotCount.Value then
			return (Promise :: any).rejected(`Index {slotIndex} exceeds max of {self.MaxSlotCount.Value}`)
		end

		local data = {
			SlotIndex = slotIndex,
			SlotName = (metadata and metadata.SlotName) or `Slot {slotIndex}`,
			CreatedTime = os.time(),
			Summary = metadata and metadata.Summary,
		}

		self:_buildSlot(slotIndex, data, true)
	end)
end

--[=[
	Deletes the slot at the given index
]=]
function HasSaveSlots.PromiseDeleteSlot(self: HasSaveSlots, slotIndex: number): Promise.Promise<any>
	return (self._loadPromise :: any):Then(function()
		if slotIndex == self.ActiveSlotIndex.Value then
			return (Promise :: any).rejected("Cannot delete active slot")
		end

		local slot = self._slotMap[slotIndex]
		if not slot then
			return (Promise :: any).rejected(`Slot {slotIndex} not found`)
		end

		slot.maid:Destroy()

		local slotKey = tostring(slotIndex)
		self._metadataStore:Delete(slotKey)
		self._dataStore:GetSubStore("saveSlots"):Delete(slotKey)
	end)
end

--[=[
	Sets the metadata for the slot at the given index
]=]
function HasSaveSlots.PromiseSetSlotMetadata(
	self: HasSaveSlots,
	slotIndex: number,
	data: SaveSlotData.SaveSlotMetadata
): Promise.Promise<any>
	assert(data.SlotIndex == nil or data.SlotIndex == slotIndex, "SlotIndex is locked")

	return (self._loadPromise :: any):Then(function()
		local slot = self._slotMap[slotIndex]
		SaveSlotData:Set(slot.folder, data)
	end)
end

--[=[
	Gets the metadata for the slot at the given index
]=]
function HasSaveSlots.PromiseGetSlotMetadata(
	self: HasSaveSlots,
	slotIndex: number
): Promise.Promise<SaveSlotData.SaveSlotMetadata>
	return (self._loadPromise :: any):Then(function()
		local slot = self._slotMap[slotIndex]
		return (Promise :: any).resolved(slot and slot.attributes)
	end)
end

--[=[
	Gets the last active slot index
]=]
function HasSaveSlots.PromiseLastActiveSlotIndex(self: HasSaveSlots): Promise.Promise<number?>
	return (self._loadPromise :: any):Then(function()
		return self.ActiveSlotIndex.Value or self._lastActiveSlotIndex
	end)
end

--[=[
	Sets the summary provider callback
]=]
function HasSaveSlots.SetSummaryProvider(self: HasSaveSlots, provider: ((Player, any) -> string)?): ()
	self._summaryProvider = provider
end

--[=[
	Refreshes the active slot summary
]=]
function HasSaveSlots.PromiseRefreshActiveSlotSummary(self: HasSaveSlots): Promise.Promise<any>
	return (self._loadPromise :: any):Then(function()
		self:_refreshActiveSlotSummary()
	end)
end

function HasSaveSlots._promiseLoadSlots(self: HasSaveSlots): Promise.Promise<{}>
	return self._maid:GivePromise(self._playerDataStoreService:PromiseDataStore(self._obj)):Then(function(dataStore)
		self._dataStore = dataStore
		self._metadataStore = dataStore:GetSubStore("saveSlotMetadata")

		self._maid:GiveTask(self._dataStore:AddSavingCallback(function()
			self:_refreshActiveSlotSummary()
		end))

		return self._metadataStore:LoadAll({}):Then(function(metadata)
			for key, data in metadata do
				local slotIndex = tonumber(key)
				if slotIndex then
					self:_buildSlot(slotIndex, data)
				end
			end

			return dataStore:Load("ActiveSlotIndex"):Then(function(activeIndex: number?)
				self._lastActiveSlotIndex = activeIndex
				self._maid:GiveTask(dataStore:StoreOnValueChange("ActiveSlotIndex", self.ActiveSlotIndex))
			end)
		end)
	end)
end

function HasSaveSlots._buildSlot(
	self: HasSaveSlots,
	slotIndex: number,
	data: SaveSlotData.SaveSlotMetadata,
	isNew: boolean?
): ()
	local maid = self._maid:Add(Maid.new())

	local folder = maid:Add(Instance.new("Folder"))
	folder.Name = tostring(slotIndex)
	folder.Archivable = false

	local attributes = SaveSlotData:Create(folder)
	attributes.SlotIndex.Value = slotIndex

	local slotStore = self._metadataStore:GetSubStore(tostring(slotIndex))

	for _, key in { "SlotName", "CreatedTime", "LastPlayedTime", "Summary" } do
		attributes[key].Value = data[key]
		maid:GiveTask(slotStore:StoreOnValueChange(key, attributes[key]))

		if isNew then
			slotStore:Store(key, attributes[key].Value)
		end
	end

	folder.Parent = self._slotContainer

	self._slotMap[slotIndex] = {
		folder = folder,
		attributes = attributes,
		maid = maid,
	}

	maid:GiveTask(function()
		self._slotMap[slotIndex] = nil
	end)
end

function HasSaveSlots._refreshActiveSlotSummary(self: HasSaveSlots): ()
	if not self._summaryProvider then
		return -- No summary provider
	end

	local activeSlotIndex = self.ActiveSlotIndex.Value
	local activeSlot = activeSlotIndex and self._slotMap[activeSlotIndex]
	if not activeSlot then
		return -- No active slot
	end

	local slotStore = self._dataStore:GetSubStore("saveSlots"):GetSubStore(tostring(activeSlotIndex))
	local success, result = pcall(self._summaryProvider, self._obj, slotStore)

	if not success then
		warn(`[HasSaveSlots] Summary provider errored: {result}`)
		return
	end

	if type(result) ~= "string" then
		warn(`[HasSaveSlots] Summary provider returned non-string ({typeof(result)})`)
		return
	end

	activeSlot.attributes.Summary.Value = result

	-- Store directly to avoid deferral during save callback
	self._metadataStore:GetSubStore(tostring(activeSlotIndex)):Store("Summary", result)
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

	self._maid:GiveTask(self._remoting.PromiseLastActiveSlotIndex:Bind(function(remotePlayer)
		if remotePlayer == self._obj then
			return self:PromiseLastActiveSlotIndex()
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseRefreshActiveSlotSummary:Bind(function(remotePlayer)
		if remotePlayer == self._obj then
			return self:PromiseRefreshActiveSlotSummary()
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))
end

return PlayerBinder.new("HasSaveSlots", HasSaveSlots :: any) :: Binder.Binder<HasSaveSlots>
