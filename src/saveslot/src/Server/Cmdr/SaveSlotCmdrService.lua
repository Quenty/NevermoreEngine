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
		Description = "Creates save slots. Defaults to the lowest free index when none is given.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Slots",
				Type = "numbers",
				Description = "Slot indices to create (e.g. 1,2). Omit to use the lowest free index.",
				Optional = true,
			},
		},
	}, function(context, slotIndices: { number }?)
		local maxSlotCount = context.Executor:GetAttribute("MaxSlotCount")

		-- Track indices already taken so a batch fills gaps and never collides within itself.
		local used = {}
		for _, metadata in self._saveSlotDataService:GetSlotList(context.Executor) do
			used[metadata.SlotIndex] = true
		end

		local toCreate = {}
		if slotIndices == nil then
			-- Default to the lowest free index, filling gaps left by deletions.
			local freeIndex = 1
			while used[freeIndex] do
				freeIndex += 1
			end

			if freeIndex > maxSlotCount then
				return "All slots are already in use."
			end

			table.insert(toCreate, freeIndex)
		else
			-- Validate the whole batch up front so nothing is created when any index is bad.
			local seen = {}
			for _, slotIndex in slotIndices do
				if (slotIndex < 1) or (slotIndex > maxSlotCount) then
					return `Index must be in range [1, {maxSlotCount}].`
				end
				if used[slotIndex] then
					return `Slot {slotIndex} already exists.`
				end
				if not seen[slotIndex] then
					seen[slotIndex] = true
					table.insert(toCreate, slotIndex)
				end
			end
		end

		self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				-- Create sequentially to avoid concurrent datastore saves.
				local promise = Promise.resolved()
				for _, slotIndex in toCreate do
					promise = promise:Then(function()
						return hasSaveSlots:PromiseCreateSlot(slotIndex)
					end)
				end
				return promise
			end)
			:Wait()

		return `Created slot(s) {table.concat(toCreate, ", ")}.`
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
		Description = "Duplicates save slots into new slots at the lowest free indices.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to duplicate (e.g. 1,2, . for your current slot, or * for all).",
			},
		},
	}, function(context, slotIndices: { number })
		-- Resolve indices to ids up front; `*`/`.` can include duplicates.
		local seen = {}
		local toDuplicate = {}
		for _, slotIndex in slotIndices do
			local slotId = self._saveSlotDataService:GetSlotIdFromIndex(context.Executor, slotIndex)
			if slotId and not seen[slotId] then
				seen[slotId] = true
				table.insert(toDuplicate, { slotIndex = slotIndex, slotId = slotId })
			end
		end

		if #toDuplicate == 0 then
			return "No matching slots to duplicate."
		end

		local lines = self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				-- Duplicate sequentially: each copy consumes a free index the next one must see. Report
				-- per-slot so a mid-batch failure (e.g. the roster filling up) still surfaces the successes.
				local promise = Promise.resolved()
				local results = {}
				for _, entry in toDuplicate do
					promise = promise:Then(function()
						return hasSaveSlots
							:PromiseDuplicateSlot(entry.slotId)
							:Then(function(newSlotId)
								local newMetadata =
									self._saveSlotDataService:GetSlotMetadata(context.Executor, newSlotId)
								table.insert(
									results,
									`slot {entry.slotIndex} → slot {newMetadata.SlotIndex} ("{newMetadata.SlotName}")`
								)
							end)
							:Catch(function(err)
								table.insert(results, `slot {entry.slotIndex}: {tostring(err)}`)
							end)
					end)
				end
				return promise:Then(function()
					return results
				end)
			end)
			:Wait()

		return `Duplicated:\n{table.concat(lines, "\n")}`
	end)

	self._cmdrService:RegisterCommand({
		Name = "reset-save-slot",
		Description = "Resets save slots to fresh empty ones, keeping their index and name.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to reset (e.g. 1,2, . for your current slot, or * for all). Omit to reset the active slot.",
				Optional = true,
			},
		},
	}, function(context, slotIndices: { number }?)
		local toReset = {}
		if slotIndices == nil then
			-- No indices given: reset the active slot.
			local activeSlotId = self._saveSlotDataService:GetActiveSlotId(context.Executor)
			if not activeSlotId then
				return "No active slot."
			end

			local metadata = self._saveSlotDataService:GetSlotMetadata(context.Executor, activeSlotId)
			table.insert(toReset, { slotIndex = metadata.SlotIndex, slotId = activeSlotId })
		else
			-- Resolve indices to ids up front; `*`/`.` can include duplicates.
			local seen = {}
			for _, slotIndex in slotIndices do
				local slotId = self._saveSlotDataService:GetSlotIdFromIndex(context.Executor, slotIndex)
				if slotId and not seen[slotId] then
					seen[slotId] = true
					table.insert(toReset, { slotIndex = slotIndex, slotId = slotId })
				end
			end

			if #toReset == 0 then
				return "No matching slots to reset."
			end
		end

		local resetIndices = self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				-- Reset sequentially to avoid concurrent datastore saves.
				local promise = Promise.resolved()
				local done = {}
				for _, entry in toReset do
					promise = promise:Then(function()
						return hasSaveSlots:PromiseResetSlot(entry.slotId):Then(function()
							table.insert(done, entry.slotIndex)
						end)
					end)
				end
				return promise:Then(function()
					return done
				end)
			end)
			:Wait()

		table.sort(resetIndices)
		return `Reset slot(s) {table.concat(resetIndices, ", ")}.`
	end)

	self._cmdrService:RegisterCommand({
		Name = "export-save-slot",
		Description = "Exports a save slot to the shared store and prints its code.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Player",
				Type = "player",
				Description = "Player whose slot to export (defaults to you).",
				Optional = true,
			},
			{
				Name = "Slot",
				Type = "number",
				Description = "Slot index to export (defaults to the active slot).",
				Optional = true,
			},
			{
				Name = "Code",
				Type = "string",
				Description = "Code to store under (defaults to a generated one).",
				Optional = true,
			},
		},
	}, function(context, player: Player?, slotIndex: number?, code: string?)
		local targetPlayer = player or context.Executor

		local exportSlotId: string
		if slotIndex then
			local resolved = self._saveSlotDataService:GetSlotIdFromIndex(targetPlayer, slotIndex)
			if not resolved then
				return `No slot with index {slotIndex}.`
			end
			exportSlotId = resolved
		else
			local active = self._saveSlotDataService:GetActiveSlotId(targetPlayer)
			if not active then
				return "No active slot to export."
			end
			exportSlotId = active
		end

		return self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(targetPlayer))
			:Then(function(hasSaveSlots)
				if code then
					return hasSaveSlots:PromiseSaveSlotToSharedDataStore(exportSlotId, code):Then(function()
						return code
					end)
				end
				return hasSaveSlots:PromiseExportSaveSlotToCode(exportSlotId)
			end)
			:Then(function(resultCode)
				return `Exported save slot to code: {resultCode}`
			end)
			:Catch(function(err)
				return `Export failed: {tostring(err)}`
			end)
			:Wait()
	end)

	self._cmdrService:RegisterCommand({
		Name = "load-ephemeral-save-slot",
		Description = "Loads a save slot code into a throwaway ephemeral slot and selects it.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Code",
				Type = "string",
				Description = "The code to load.",
			},
		},
	}, function(context, code: string)
		return self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseLoadEphemeralSaveSlotFromCode(code)
			end)
			:Then(function()
				return `Loaded ephemeral save slot from code: {code}`
			end)
			:Catch(function(err)
				return `Load failed: {tostring(err)}`
			end)
			:Wait()
	end)
end

function SaveSlotCmdrService.Destroy(self: SaveSlotCmdrService): ()
	self._maid:Destroy()
end

return SaveSlotCmdrService
