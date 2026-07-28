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
local SaveSlotConstants = require("SaveSlotConstants")
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
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to list slots for (e.g. . for yourself, or * for everyone).",
			},
		},
	}, function(_context, players: { Player })
		local listString = ""

		for _, player in players do
			local activeSlotId = self._saveSlotDataService:GetActiveSlotId(player)
			local slotList = self._saveSlotDataService:GetSlotList(player)

			listString ..= `\n{player.Name}:\n`
			if #slotList == 0 then
				listString ..= "No slots.\n"
			end

			for _, slot in slotList do
				local isActive = (slot.SlotId == activeSlotId)
				listString ..= `\n"{slot.SlotName}" ({slot.SlotIndex}){isActive and " — Active" or ""}\n{slot.Summary}\n`
			end

			-- An ephemeral session is not a save, so it is absent from the slot list above -- but it is what
			-- the player is playing right now and the thing persist-save-slot acts on, so list it under the
			-- reserved index the other commands address it by.
			if self._saveSlotDataService:IsActiveSlotEphemeral(player) then
				local metadata = self._saveSlotDataService:GetActiveSlotMetadata(player)
				listString ..= `\n"{metadata.SlotName}" ({metadata.SlotIndex}) — Active, ephemeral\n{metadata.Summary}\n`
			end
		end

		return listString
	end)

	self._cmdrService:RegisterCommand({
		Name = "get-active-save-slot",
		Description = "Returns the active save slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to query (e.g. . for yourself, or * for everyone).",
			},
		},
	}, function(_context, players: { Player })
		local lines = {}

		for _, player in players do
			local activeSlotId = self._saveSlotDataService:GetActiveSlotId(player)
			if activeSlotId then
				local slotData = self._saveSlotDataService:GetSlotMetadata(player, activeSlotId)
				table.insert(lines, `{player.Name} is using slot {slotData.SlotIndex} ("{slotData.SlotName}").`)
			else
				table.insert(lines, `{player.Name} has no active slot.`)
			end
		end

		return table.concat(lines, "\n")
	end)

	self._cmdrService:RegisterCommand({
		Name = "set-save-slot",
		Description = "Switches to the given save slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to switch (e.g. . for yourself, or * for everyone).",
			},
			{
				Name = "Slot",
				Type = "slotIndex",
				Description = "Slot index to switch to, or . for your current slot.",
			},
		},
	}, function(_context, players: { Player }, slotIndex: number)
		local lines = self:_promisePlayerLines(players, function(hasSaveSlots, player)
			local slotId = self:_getSlotIdFromIndex(player, slotIndex)
			if not slotId then
				return `{player.Name} has no slot with index {slotIndex}.`
			end

			if slotId == self._saveSlotDataService:GetActiveSlotId(player) then
				return `{player.Name} already has slot {slotIndex} active.`
			end

			return hasSaveSlots:PromiseSelectSlot(slotId):Then(function()
				return `{player.Name} switched to slot {slotIndex}.`
			end)
		end):Wait()

		return table.concat(lines, "\n")
	end)

	self._cmdrService:RegisterCommand({
		Name = "deselect-save-slot",
		Description = "Clears the active save slot, returning to a no-slot state.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to deselect (e.g. . for yourself, or * for everyone).",
			},
		},
	}, function(_context, players: { Player })
		local lines = self:_promisePlayerLines(players, function(hasSaveSlots, player)
			if not self._saveSlotDataService:GetActiveSlotId(player) then
				return `{player.Name} has no active slot.`
			end

			return hasSaveSlots:PromiseDeselectSlot():Then(function()
				return `{player.Name} deselected active slot.`
			end)
		end):Wait()

		return table.concat(lines, "\n")
	end)

	self._cmdrService:RegisterCommand({
		Name = "create-save-slot",
		Description = "Creates save slots. Defaults to the lowest free index when none is given.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to create slots for (e.g. . for yourself, or * for everyone).",
			},
			{
				Name = "Slots",
				Type = "numbers",
				Description = "Slot indices to create (e.g. 1,2). Omit to use the lowest free index.",
				Optional = true,
			},
		},
	}, function(_context, players: { Player }, slotIndices: { number }?)
		local lines = self:_promisePlayerLines(players, function(hasSaveSlots, player)
			-- The cap is per-player, so it has to come off each target rather than the executor, whose
			-- cap may be larger. Read from the binder rather than the mirrored attribute, since that is
			-- what PromiseCreateSlot itself validates against.
			local maxSlotCount = hasSaveSlots.MaxSlotCount.Value

			-- Track indices already taken so a batch fills gaps and never collides within itself.
			local used = {}
			for _, metadata in self._saveSlotDataService:GetSlotList(player) do
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
					return `{player.Name}: all slots are already in use.`
				end

				table.insert(toCreate, freeIndex)
			else
				-- Validate the whole batch up front so nothing is created when any index is bad.
				local seen = {}
				for _, slotIndex in slotIndices do
					if (slotIndex < 1) or (slotIndex > maxSlotCount) then
						return `{player.Name}: index must be in range [1, {maxSlotCount}].`
					end
					if used[slotIndex] then
						return `{player.Name}: slot {slotIndex} already exists.`
					end
					if not seen[slotIndex] then
						seen[slotIndex] = true
						table.insert(toCreate, slotIndex)
					end
				end
			end

			-- Create sequentially to avoid concurrent datastore saves.
			local promise = Promise.resolved()
			for _, slotIndex in toCreate do
				promise = promise:Then(function()
					return hasSaveSlots:PromiseCreateSlot(slotIndex)
				end)
			end

			return promise:Then(function()
				return `{player.Name} created slot(s) {table.concat(toCreate, ", ")}.`
			end)
		end):Wait()

		return table.concat(lines, "\n")
	end)

	self._cmdrService:RegisterCommand({
		Name = "delete-save-slot",
		Description = "Deletes the given save slots.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to delete slots for (e.g. . for yourself, or * for everyone).",
			},
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to delete (e.g. 1,2, . for your current slot, or * for all).",
			},
		},
	}, function(_context, players: { Player }, slotIndices: { number })
		local targets = self:_resolveTargets(players, slotIndices)
		if #targets == 0 then
			return "No matching slots to delete."
		end

		local lines = self
			:_promiseSlotLines(targets, function(hasSaveSlots, entry, player)
				-- The active slot can't be deleted while selected, so deselect it first (flushing its
				-- progress) when reached. Read live rather than up front, since an earlier deletion in
				-- this batch may have already deselected it. An ephemeral session is left alone:
				-- PromiseDeleteSlot retires it itself, and deselecting first would retire it early,
				-- leaving nothing behind to delete.
				local isActive = (entry.slotId == self._saveSlotDataService:GetActiveSlotId(player))
				local deselect = if isActive and not self._saveSlotDataService:IsActiveSlotEphemeral(player)
					then hasSaveSlots:PromiseDeselectSlot()
					else Promise.resolved()

				return deselect
					:Then(function()
						return hasSaveSlots:PromiseDeleteSlot(entry.slotId)
					end)
					:Then(function()
						return `{player.Name} deleted slot {entry.slotIndex}.`
					end)
			end)
			:Wait()

		return `Deleted:\n{table.concat(lines, "\n")}`
	end)

	self._cmdrService:RegisterCommand({
		Name = "duplicate-save-slot",
		Description = "Duplicates save slots into new slots at the lowest free indices. Duplicating an ephemeral session saves it without switching onto the copy -- see persist-save-slot.",
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
		Name = "persist-save-slot",
		Description = "Turns an ephemeral session into a real save slot and switches onto it.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to persist the session of (e.g. . for yourself, or * for everyone).",
			},
		},
	}, function(_context, players: { Player })
		-- Takes no slot argument: an ephemeral slot exists only while it is active, so the active slot is
		-- the only one there is to persist.
		local lines = self
			:_promisePlayerLines(players, function(hasSaveSlots, player)
				if not self._saveSlotDataService:IsActiveSlotEphemeral(player) then
					return `{player.Name} has no ephemeral session active.`
				end

				return hasSaveSlots:PromisePersistEphemeralSlot():Then(function(newSlotId)
					local metadata = self._saveSlotDataService:GetSlotMetadata(player, newSlotId)
					return `{player.Name} persisted their session to slot {metadata.SlotIndex} ("{metadata.SlotName}").`
				end)
			end)
			:Wait()

		return table.concat(lines, "\n")
	end)

	self._cmdrService:RegisterCommand({
		Name = "reset-save-slot",
		Description = "Resets save slots to fresh empty ones, keeping their index and name.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to reset slots for (e.g. . for yourself, or * for everyone).",
			},
			{
				-- Required rather than defaulting to the active slot: with Players ahead of it, an
				-- optional Slots would leave `reset-save-slot *` as valid syntax that wipes the active
				-- slot of every player in the server.
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to reset (e.g. 1,2, . for your current slot, or * for all).",
			},
		},
	}, function(_context, players: { Player }, slotIndices: { number })
		local targets = self:_resolveTargets(players, slotIndices)
		if #targets == 0 then
			return "No matching slots to reset."
		end

		local lines = self:_promiseSlotLines(targets, function(hasSaveSlots, entry, player)
			return hasSaveSlots:PromiseResetSlot(entry.slotId):Then(function()
				return `{player.Name} reset slot {entry.slotIndex}.`
			end)
		end):Wait()

		return `Reset:\n{table.concat(lines, "\n")}`
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

		-- Admin tooling exports the main slot too, which the normal path refuses. See
		-- HasSaveSlots.PromiseExportSlot for what that carries.
		local lines = self:_promiseSlotLines(targets, function(hasSaveSlots, entry, player)
			return hasSaveSlots:PromiseExportSaveSlotToCode(entry.slotId, true):Then(function(code)
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

		-- Admin tooling exports the main slot too, which the normal path refuses. See
		-- HasSaveSlots.PromiseExportSlot for what that carries.
		local blocks = self:_promiseSlotLines(targets, function(hasSaveSlots, entry, player)
			return hasSaveSlots:PromiseExportSaveSlotToJson(entry.slotId, true):Then(function(json)
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

-- Resolves a slot index to the player's slot id, including the reserved ephemeral index (see
-- [SaveSlotCmdrUtils]). The data service's index lookup only walks the save list, which an ephemeral slot
-- is excluded from, so that one index resolves against the active slot instead.
function SaveSlotCmdrService._getSlotIdFromIndex(self: SaveSlotCmdrService, player: Player, slotIndex: number): string?
	if slotIndex == SaveSlotConstants.EPHEMERAL_SLOT_INDEX then
		if self._saveSlotDataService:IsActiveSlotEphemeral(player) then
			return self._saveSlotDataService:GetActiveSlotId(player)
		end
		return nil
	end

	return self._saveSlotDataService:GetSlotIdFromIndex(player, slotIndex)
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
			local slotId = self:_getSlotIdFromIndex(player, slotIndex)
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

-- Runs handlePlayer once per player, sequentially, to avoid concurrent datastore writes. For the
-- commands that act on a player as a whole rather than on a resolved slot list. handlePlayer may
-- return a line directly to report without doing any work.
function SaveSlotCmdrService._promisePlayerLines(
	self: SaveSlotCmdrService,
	players: { Player },
	handlePlayer: (any, Player) -> any
): any
	local promise = Promise.resolved()
	local results: { string } = {}

	for _, player in players do
		promise = promise:Then(function()
			return self._maid
				:GivePromise(self._hasSaveSlotsBinder:Promise(player))
				:Then(function(hasSaveSlots)
					return handlePlayer(hasSaveSlots, player)
				end)
				:Then(function(line)
					table.insert(results, line)
				end)
				:Catch(function(err)
					table.insert(results, `{player.Name}: {tostring(err)}`)
				end)
		end)
	end

	return promise:Then(function()
		return results
	end)
end

-- Runs handleSlot over every resolved slot of every target, sequentially, to avoid concurrent
-- datastore writes. Reports per-slot so a mid-batch failure (e.g. one player's slot failing to
-- load) still surfaces the successes.
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
