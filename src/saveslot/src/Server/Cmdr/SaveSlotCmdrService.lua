--!strict
--[=[
	@class SaveSlotCmdrService
]=]

local require = require(script.Parent.loader).load(script)

local CmdrService = require("CmdrService")
local HasSaveSlots = require("HasSaveSlots")
local Maid = require("Maid")
local Promise = require("Promise")
local SaveSlotCmdrUtils = require("SaveSlotCmdrUtils")
local SaveSlotDataService = require("SaveSlotDataService")
local ServiceBag = require("ServiceBag")

local SaveSlotCmdrService = {}
SaveSlotCmdrService.ServiceName = "SaveSlotCmdrService"

export type SaveSlotCmdrService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrService: any,
		_hasSaveSlotsBinder: any,
		_saveSlotDataService: any,
	},
	{} :: typeof({ __index = SaveSlotCmdrService })
))

function SaveSlotCmdrService.Init(self: SaveSlotCmdrService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._cmdrService = self._serviceBag:GetService(CmdrService)

	-- Internal
	self._hasSaveSlotsBinder = self._serviceBag:GetService(HasSaveSlots)
	self._saveSlotDataService = self._serviceBag:GetService(SaveSlotDataService)
end

function SaveSlotCmdrService.Start(self: SaveSlotCmdrService)
	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function(cmdr)
		SaveSlotCmdrUtils.registerSlotIndexType(cmdr, self._saveSlotDataService)
		self:_registerCommands()
	end)
end

function SaveSlotCmdrService._registerCommands(self: SaveSlotCmdrService): ()
	self._cmdrService:RegisterCommand({
		Name = "list-save-slots",
		Description = "Lists all save slots.",
		Group = "SaveSlots",
		Args = {},
	}, function(context)
		local activeSlotId = self._saveSlotDataService:GetActiveSlotId(context.Executor)
		local slotList = self._saveSlotDataService:GetSlotList(context.Executor)
		local listString = ""

		for _, slot in slotList do
			local isActive = (slot.SlotId == activeSlotId)
			listString ..= `\n"{slot.SlotName}" ({slot.SlotIndex}){isActive and " — Active" or ""}\n{slot.Summary}\n`
		end

		return listString
	end)

	self._cmdrService:RegisterCommand({
		Name = "get-active-save-slot",
		Description = "Returns the active save slot.",
		Group = "SaveSlots",
		Args = {},
	}, function(context)
		local activeSlotId = self._saveSlotDataService:GetActiveSlotId(context.Executor)
		if not activeSlotId then
			return "No active slot."
		end

		local slotData = self._saveSlotDataService:GetSlotMetadata(context.Executor, activeSlotId)

		return `Currently using slot {slotData.SlotIndex} ("{slotData.SlotName}").`
	end)

	self._cmdrService:RegisterCommand({
		Name = "set-save-slot",
		Description = "Switches to the given save slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Slot",
				Type = "slotIndex",
				Description = "Slot index to switch to, or . for your current slot.",
			},
		},
	}, function(context, slotIndex: number)
		local slotId = self._saveSlotDataService:GetSlotIdFromIndex(context.Executor, slotIndex)
		if not slotId then
			return `No slot with index {slotIndex}.`
		end

		if slotId == self._saveSlotDataService:GetActiveSlotId(context.Executor) then
			return "Slot is already active."
		end

		self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseSelectSlot(slotId)
			end)
			:Wait()

		return `Switched to slot {slotIndex}.`
	end)

	self._cmdrService:RegisterCommand({
		Name = "deselect-save-slot",
		Description = "Clears the active save slot, returning to a no-slot state.",
		Group = "SaveSlots",
		Args = {},
	}, function(context)
		if not self._saveSlotDataService:GetActiveSlotId(context.Executor) then
			return "No active slot."
		end

		self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseDeselectSlot()
			end)
			:Wait()

		return "Deselected active slot."
	end)

	self._cmdrService:RegisterCommand({
		Name = "create-save-slot",
		Description = "Creates a save slot. Defaults to the lowest free index when none is given.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Slot",
				Type = "number",
				Description = "Slot index to create. Omit to use the lowest free index.",
				Optional = true,
			},
		},
	}, function(context, slotIndex: number?)
		local maxSlotCount = context.Executor:GetAttribute("MaxSlotCount")

		if slotIndex == nil then
			-- Default to the lowest free index, filling gaps left by deletions.
			local used = {}
			for _, metadata in self._saveSlotDataService:GetSlotList(context.Executor) do
				used[metadata.SlotIndex] = true
			end

			local freeIndex = 1
			while used[freeIndex] do
				freeIndex += 1
			end

			if freeIndex > maxSlotCount then
				return "All slots are already in use."
			end

			slotIndex = freeIndex
		elseif (slotIndex < 1) or (slotIndex > maxSlotCount) then
			return `Index must be in range [1, {maxSlotCount}].`
		end

		local slotId = self._saveSlotDataService:GetSlotIdFromIndex(context.Executor, slotIndex)
		if slotId then
			return "Slot already exists."
		end

		self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseCreateSlot(slotIndex)
			end)
			:Wait()

		return `Created slot {slotIndex}.`
	end)

	self._cmdrService:RegisterCommand({
		Name = "delete-save-slot",
		Description = "Deletes the given save slots.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to delete (e.g. 1,2, . for your current slot, or * for all).",
			},
		},
	}, function(context, slotIndices: { number })
		local activeSlotId = self._saveSlotDataService:GetActiveSlotId(context.Executor)

		-- Resolve indices to ids up front; `*` can include the active slot and duplicates.
		local seen = {}
		local toDelete = {}
		for _, slotIndex in slotIndices do
			local slotId = self._saveSlotDataService:GetSlotIdFromIndex(context.Executor, slotIndex)
			if slotId and not seen[slotId] then
				seen[slotId] = true
				table.insert(toDelete, { slotIndex = slotIndex, slotId = slotId })
			end
		end

		if #toDelete == 0 then
			return "No matching slots to delete."
		end

		self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				-- Delete sequentially to avoid concurrent datastore saves. The active slot can't be
				-- deleted while selected, so deselect it first (flushing its progress) when reached.
				local promise = Promise.resolved()
				for _, entry in toDelete do
					promise = promise:Then(function()
						if entry.slotId == activeSlotId then
							return hasSaveSlots:PromiseDeselectSlot():Then(function()
								return hasSaveSlots:PromiseDeleteSlot(entry.slotId)
							end)
						end

						return hasSaveSlots:PromiseDeleteSlot(entry.slotId)
					end)
				end
				return promise
			end)
			:Wait()

		local deletedIndices = {}
		for _, entry in toDelete do
			table.insert(deletedIndices, entry.slotIndex)
		end

		return `Deleted slot(s) {table.concat(deletedIndices, ", ")}.`
	end)

	self._cmdrService:RegisterCommand({
		Name = "duplicate-save-slot",
		Description = "Duplicates a save slot into a new slot at the lowest free index.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Slot",
				Type = "slotIndex",
				Description = "Slot index to duplicate, or . for your current slot.",
			},
		},
	}, function(context, slotIndex: number)
		local slotId = self._saveSlotDataService:GetSlotIdFromIndex(context.Executor, slotIndex)
		if not slotId then
			return `No slot with index {slotIndex}.`
		end

		-- Mirror the binder's lowest-free-index pick so a full roster reports cleanly instead of throwing.
		local maxSlotCount = context.Executor:GetAttribute("MaxSlotCount")
		local used = {}
		for _, metadata in self._saveSlotDataService:GetSlotList(context.Executor) do
			used[metadata.SlotIndex] = true
		end
		local freeIndex = 1
		while used[freeIndex] do
			freeIndex += 1
		end
		if freeIndex > maxSlotCount then
			return "All slots are already in use."
		end

		local newSlotId = self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseDuplicateSlot(slotId)
			end)
			:Wait()

		local newMetadata = self._saveSlotDataService:GetSlotMetadata(context.Executor, newSlotId)

		return `Duplicated slot {slotIndex} into slot {newMetadata.SlotIndex} ("{newMetadata.SlotName}").`
	end)
end

function SaveSlotCmdrService.Destroy(self: SaveSlotCmdrService): ()
	self._maid:Destroy()
end

return SaveSlotCmdrService
