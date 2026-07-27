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

type SlotEntry = { slotIndex: number, slotId: string }
type SlotEntries = { SlotEntry }

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
				Name = "Players",
				Type = "players",
				Description = "Players to duplicate slots for (e.g. . for yourself, or * for everyone).",
			},
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to duplicate (e.g. 1,2, . for your current slot, or * for all).",
			},
		},
	}, function(_context, players: { Player }, slotIndices: { number })
		local targets = self:_resolveTargets(players, slotIndices)
		if #targets == 0 then
			return "No matching slots to duplicate."
		end

		-- Each copy consumes a free index the next one must see, which the sequential walk guarantees.
		local lines = self
			:_promiseSlotLines(targets, function(hasSaveSlots, entry, player)
				return hasSaveSlots:PromiseDuplicateSlot(entry.slotId):Then(function(newSlotId)
					local newMetadata = self._saveSlotDataService:GetSlotMetadata(player, newSlotId)
					return `{player.Name} slot {entry.slotIndex} → slot {newMetadata.SlotIndex} ("{newMetadata.SlotName}")`
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
		Description = "Exports save slots to the shared store and prints their codes.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to export from (e.g. . for yourself, or * for everyone).",
			},
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to export (e.g. 1,2, . for your current slot, or * for all). Omit for each player's active slot.",
				Optional = true,
			},
		},
	}, function(_context, players: { Player }, slotIndices: { number }?)
		local targets = self:_resolveTargets(players, slotIndices)
		if #targets == 0 then
			return "No matching slots to export."
		end

		local lines = self:_promiseSlotLines(targets, function(hasSaveSlots, entry, player)
			return hasSaveSlots:PromiseExportSaveSlotToCode(entry.slotId):Then(function(code)
				return `{player.Name} slot {entry.slotIndex} → {code}`
			end)
		end):Wait()

		return `Exported:\n{table.concat(lines, "\n")}`
	end)

	self._cmdrService:RegisterCommand({
		Name = "export-save-slot-json",
		Description = "Exports save slots as raw JSON (no shared store) and prints them.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to export from (e.g. . for yourself, or * for everyone).",
			},
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to export (e.g. 1,2, . for your current slot, or * for all). Omit for each player's active slot.",
				Optional = true,
			},
		},
	}, function(_context, players: { Player }, slotIndices: { number }?)
		local targets = self:_resolveTargets(players, slotIndices)
		if #targets == 0 then
			return "No matching slots to export."
		end

		local blocks = self:_promiseSlotLines(targets, function(hasSaveSlots, entry, player)
			return hasSaveSlots:PromiseExportSaveSlotToJson(entry.slotId):Then(function(json)
				return `-- {player.Name} slot {entry.slotIndex}\n{json}`
			end)
		end):Wait()

		return table.concat(blocks, "\n\n")
	end)

	self._cmdrService:RegisterCommand({
		Name = "import-save-slot",
		Description = "Imports a save slot code into a new persisted (non-main) slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Player",
				Type = "player",
				Description = "Player to import into (e.g. . for yourself).",
			},
			{
				Name = "Code",
				Type = "string",
				Description = "The code to import.",
			},
		},
	}, function(_context, player: Player, code: string)
		return self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(player))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseImportSlotFromSharedDataStore(code)
			end)
			:Then(function(newSlotId)
				local metadata = self._saveSlotDataService:GetSlotMetadata(player, newSlotId)
				return `Imported save slot from code into {player.Name} slot {metadata.SlotIndex} ("{metadata.SlotName}").`
			end)
			:Catch(function(err)
				return `Import failed: {tostring(err)}`
			end)
			:Wait()
	end)

	self._cmdrService:RegisterCommand({
		Name = "import-ephemeral-save-slot",
		Description = "Imports a save slot code into a throwaway ephemeral slot and selects it.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Player",
				Type = "player",
				Description = "Player to import into (e.g. . for yourself).",
			},
			{
				Name = "Code",
				Type = "string",
				Description = "The code to load.",
			},
		},
	}, function(_context, player: Player, code: string)
		return self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(player))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseImportEphemeralSaveSlotFromCode(code)
			end)
			:Then(function()
				return `Imported ephemeral save slot into {player.Name} from code: {code}`
			end)
			:Catch(function(err)
				return `Load failed: {tostring(err)}`
			end)
			:Wait()
	end)
end

-- Resolves a slotIndices argument (or nil = the active slot) into de-duplicated { slotIndex, slotId }
-- entries for the player. An empty result means nothing matched, and the caller reports it.
function SaveSlotCmdrService._resolveSlotEntries(
	self: SaveSlotCmdrService,
	player: Player,
	slotIndices: { number }?
): SlotEntries
	local entries = {}
	if slotIndices == nil then
		local activeSlotId = self._saveSlotDataService:GetActiveSlotId(player)
		if not activeSlotId then
			return entries
		end
		local metadata = self._saveSlotDataService:GetSlotMetadata(player, activeSlotId)
		table.insert(entries, { slotIndex = metadata.SlotIndex, slotId = activeSlotId })
	else
		local seen = {}
		for _, slotIndex in slotIndices do
			local slotId = self._saveSlotDataService:GetSlotIdFromIndex(player, slotIndex)
			if slotId and not seen[slotId] then
				seen[slotId] = true
				table.insert(entries, { slotIndex = slotIndex, slotId = slotId })
			end
		end
	end
	return entries
end

-- Pairs each player with their resolved slots, dropping players with nothing to act on. Note that
-- Cmdr resolves the "." and "*" slot operators against the executor's slot list, since types only
-- see the executor, so indices given that way come from the executor's slots.
function SaveSlotCmdrService._resolveTargets(
	self: SaveSlotCmdrService,
	players: { Player },
	slotIndices: { number }?
): { { player: Player, entries: SlotEntries } }
	local targets = {}
	for _, player in players do
		local entries = self:_resolveSlotEntries(player, slotIndices)
		if #entries > 0 then
			table.insert(targets, { player = player, entries = entries })
		end
	end
	return targets
end

-- Runs handleSlot over every resolved slot of every target, sequentially, to avoid concurrent
-- datastore writes. Reports per-slot so a mid-batch failure (e.g. the main slot, which export
-- refuses) still surfaces the successes.
function SaveSlotCmdrService._promiseSlotLines(
	self: SaveSlotCmdrService,
	targets: { { player: Player, entries: SlotEntries } },
	handleSlot: (any, SlotEntry, Player) -> any
): any
	local promise = Promise.resolved()
	local results: { string } = {}

	for _, target in targets do
		promise = promise:Then(function()
			return self._maid:GivePromise(self._hasSaveSlotsBinder:Promise(target.player)):Then(function(hasSaveSlots)
				local slotPromise = Promise.resolved()
				for _, entry in target.entries do
					slotPromise = slotPromise:Then(function()
						return handleSlot(hasSaveSlots, entry, target.player)
							:Then(function(line)
								table.insert(results, line)
							end)
							:Catch(function(err)
								table.insert(results, `{target.player.Name} slot {entry.slotIndex}: {tostring(err)}`)
							end)
					end)
				end
				return slotPromise
			end)
		end)
	end

	return promise:Then(function()
		return results
	end)
end

function SaveSlotCmdrService.Destroy(self: SaveSlotCmdrService): ()
	self._maid:Destroy()
end

return SaveSlotCmdrService
