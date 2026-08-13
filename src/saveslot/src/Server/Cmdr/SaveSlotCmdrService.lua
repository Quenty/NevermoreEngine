--!strict
--[=[
	Save slot admin commands.

	Every command takes `playerIds`, so it reaches a player who is not in this server as readily as one
	who is: a player here is acted on through their bound [HasSaveSlots], and an absent player through
	an [OfflineSaveSlots] opened over their datastore. Both hand back the same
	[HasSaveSlotsDataStore], so the command bodies below never branch on which it was.

	:::warning
	Acting on an absent player **steals their session lock**, kicking them from wherever they are
	playing. That is accepted for admin tooling -- the session is released again as soon as the command
	finishes, so they can rejoin -- but it is why these are admin commands.
	:::

	@server
	@class SaveSlotCmdrService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local CmdrService = require("CmdrService")
local HasSaveSlots = require("HasSaveSlots")
local Maid = require("Maid")
local PlayerDataStoreService = require("PlayerDataStoreService")
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
		_playerDataStoreService: any,
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
	self._playerDataStoreService = self._serviceBag:GetService(PlayerDataStoreService)

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

-- Shared across every command, so the "which player" argument reads the same everywhere.
local PLAYERS_ARG_DESCRIPTION =
	"Players to act on (e.g. . for yourself, * for everyone here, a username, or #userId). A player who is not in this server is acted on offline, which kicks them."

function SaveSlotCmdrService._registerCommands(self: SaveSlotCmdrService): ()
	self._cmdrService:RegisterCommand({
		Name = "list-save-slots",
		Description = "Lists all save slots.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
		},
	}, function(_context, userIds: { number })
		return self:_runLines(userIds, function(slots, name)
			local activeSlotId = slots:GetActiveSlotId()
			local slotList = slots:GetSlotList()

			local listString = `\n{name}:\n`
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
			if slots:IsActiveSlotEphemeral() then
				local metadata = slots:GetActiveSlotMetadata()
				listString ..= `\n"{metadata.SlotName}" ({metadata.SlotIndex}) — Active, ephemeral\n{metadata.Summary}\n`
			end

			return listString
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "get-active-save-slot",
		Description = "Returns the active save slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
		},
	}, function(_context, userIds: { number })
		return self:_runLines(userIds, function(slots, name)
			local activeSlotId = slots:GetActiveSlotId()
			if activeSlotId then
				local slotData = slots:GetSlotMetadata(activeSlotId)
				return `{name} is using slot {slotData.SlotIndex} ("{slotData.SlotName}").`
			end

			-- Nobody is playing an offline session, so report what they would resume on instead of
			-- flatly saying there is no slot.
			local lastSlotId = slots:GetLastActiveSlotId()
			local lastMetadata = if lastSlotId then slots:GetSlotMetadata(lastSlotId) else nil
			if lastMetadata then
				return `{name} has no active slot; would resume on slot {lastMetadata.SlotIndex} ("{lastMetadata.SlotName}").`
			end

			return `{name} has no active slot.`
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "set-save-slot",
		Description = "Switches to the given save slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
			{
				Name = "Slot",
				Type = "slotIndex",
				Description = "Slot index to switch to, or . for your current slot.",
			},
		},
	}, function(_context, userIds: { number }, slotIndex: number)
		return self:_runLines(userIds, function(slots, name)
			local slotId = self:_getSlotIdFromIndex(slots, slotIndex)
			if not slotId then
				return `{name} has no slot with index {slotIndex}.`
			end

			if slotId == slots:GetActiveSlotId() then
				return `{name} already has slot {slotIndex} active.`
			end

			return slots:PromiseSelectSlot(slotId):Then(function()
				return `{name} switched to slot {slotIndex}.`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "deselect-save-slot",
		Description = "Clears the active save slot, returning to a no-slot state.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
		},
	}, function(_context, userIds: { number })
		return self:_runLines(userIds, function(slots, name)
			if not slots:GetActiveSlotId() then
				return `{name} has no active slot.`
			end

			return slots:PromiseDeselectSlot():Then(function()
				return `{name} deselected active slot.`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "create-save-slot",
		Description = "Creates save slots. Defaults to the lowest free index when none is given.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
			{
				Name = "Slots",
				Type = "numbers",
				Description = "Slot indices to create (e.g. 1,2). Omit to use the lowest free index.",
				Optional = true,
			},
		},
	}, function(_context, userIds: { number }, slotIndices: { number }?)
		return self:_runLines(userIds, function(slots, name)
			-- The cap is per-player, so it has to come off each target rather than the executor, whose
			-- cap may be larger. Read from the slot system rather than a mirrored attribute, since that
			-- is what PromiseCreateSlot itself validates against.
			local maxSlotCount = slots.MaxSlotCount.Value

			-- Track indices already taken so a batch fills gaps and never collides within itself.
			local used = {}
			for _, metadata in slots:GetSlotList() do
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
					return `{name}: all slots are already in use.`
				end

				table.insert(toCreate, freeIndex)
			else
				-- Validate the whole batch up front so nothing is created when any index is bad.
				local seen = {}
				for _, slotIndex in slotIndices do
					if (slotIndex < 1) or (slotIndex > maxSlotCount) then
						return `{name}: index must be in range [1, {maxSlotCount}].`
					end
					if used[slotIndex] then
						return `{name}: slot {slotIndex} already exists.`
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
					return slots:PromiseCreateSlot(slotIndex)
				end)
			end

			return promise:Then(function()
				return `{name} created slot(s) {table.concat(toCreate, ", ")}.`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "delete-save-slot",
		Description = "Deletes the given save slots.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to delete (e.g. 1,2, . for your current slot, or * for all).",
			},
		},
	}, function(_context, userIds: { number }, slotIndices: { number })
		return self:_runSlotLines(userIds, slotIndices, function(slots, entry, name)
			-- The active slot can't be deleted while selected, so deselect it first (flushing its
			-- progress) when reached. Read live rather than up front, since an earlier deletion in
			-- this batch may have already deselected it. An ephemeral session is left alone:
			-- PromiseDeleteSlot retires it itself, and deselecting first would retire it early,
			-- leaving nothing behind to delete.
			local isActive = (entry.slotId == slots:GetActiveSlotId())
			local deselect = if isActive and not slots:IsActiveSlotEphemeral()
				then slots:PromiseDeselectSlot()
				else Promise.resolved()

			return deselect
				:Then(function()
					return slots:PromiseDeleteSlot(entry.slotId)
				end)
				:Then(function()
					return `{name} deleted slot {entry.slotIndex}.`
				end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "duplicate-save-slot",
		Description = "Duplicates save slots into new slots at the lowest free indices. Duplicating an ephemeral session saves it without switching onto the copy -- see persist-save-slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to duplicate (e.g. 1,2, . for your current slot, or * for all).",
			},
		},
	}, function(_context, userIds: { number }, slotIndices: { number })
		-- Each copy consumes a free index the next one must see, which the sequential walk guarantees.
		return self:_runSlotLines(userIds, slotIndices, function(slots, entry, name)
			return slots:PromiseDuplicateSlot(entry.slotId):Then(function(newSlotId)
				local newMetadata = slots:GetSlotMetadata(newSlotId)
				return `{name} slot {entry.slotIndex} → slot {newMetadata.SlotIndex} ("{newMetadata.SlotName}")`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "persist-save-slot",
		Description = "Turns an ephemeral session into a real save slot and switches onto it.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
		},
	}, function(_context, userIds: { number })
		-- Takes no slot argument: an ephemeral slot exists only while it is active, so the active slot is
		-- the only one there is to persist. An absent player has no session at all, so this only ever
		-- reports on them.
		return self:_runLines(userIds, function(slots, name)
			if not slots:IsActiveSlotEphemeral() then
				return `{name} has no ephemeral session active.`
			end

			return slots:PromisePersistEphemeralSlot():Then(function(newSlotId)
				local metadata = slots:GetSlotMetadata(newSlotId)
				return `{name} persisted their session to slot {metadata.SlotIndex} ("{metadata.SlotName}").`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "reset-save-slot",
		Description = "Resets save slots to fresh empty ones, keeping their index and name.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
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
	}, function(_context, userIds: { number }, slotIndices: { number })
		return self:_runSlotLines(userIds, slotIndices, function(slots, entry, name)
			return slots:PromiseResetSlot(entry.slotId):Then(function()
				return `{name} reset slot {entry.slotIndex}.`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "export-save-slot",
		Description = "Exports save slots to the shared store and prints their codes.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to export (e.g. 1,2, . for your current slot, or * for all). Omit for each player's active slot.",
				Optional = true,
			},
		},
	}, function(_context, userIds: { number }, slotIndices: { number }?)
		-- Admin tooling exports the main slot too, which the normal path refuses. See
		-- HasSaveSlotsDataStore.PromiseExportSlot for what that carries.
		return self:_runSlotLines(userIds, slotIndices, function(slots, entry, name)
			return slots:PromiseExportSaveSlotToCode(entry.slotId, true):Then(function(code)
				return `{name} slot {entry.slotIndex} → {code}`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "export-save-slot-json",
		Description = "Exports save slots as raw JSON (no shared store) and prints them.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
			{
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to export (e.g. 1,2, . for your current slot, or * for all). Omit for each player's active slot.",
				Optional = true,
			},
		},
	}, function(_context, userIds: { number }, slotIndices: { number }?)
		-- Admin tooling exports the main slot too, which the normal path refuses. See
		-- HasSaveSlotsDataStore.PromiseExportSlot for what that carries.
		return self:_runSlotLines(userIds, slotIndices, function(slots, entry, name)
			return slots:PromiseExportSaveSlotToJson(entry.slotId, true):Then(function(json)
				return `-- {name} slot {entry.slotIndex}\n{json}`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "import-save-slot",
		Description = "Imports a save slot code into a new persisted (non-main) slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Player",
				Type = "playerId",
				Description = "Player to import into (e.g. . for yourself, a username, or #userId). A player who is not in this server is imported into offline, which kicks them.",
			},
			{
				Name = "Code",
				Type = "string",
				Description = "The code to import.",
			},
		},
	}, function(_context, userId: number, code: string)
		return self:_runLines({ userId }, function(slots, name)
			return slots:PromiseImportSlotFromSharedDataStore(code):Then(function(newSlotId)
				local metadata = slots:GetSlotMetadata(newSlotId)
				return `Imported save slot from code into {name} slot {metadata.SlotIndex} ("{metadata.SlotName}").`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "import-ephemeral-save-slot",
		Description = "Imports a save slot code into a throwaway ephemeral slot and selects it.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Player",
				Type = "playerId",
				Description = "Player to import into (e.g. . for yourself, a username, or #userId). Must be in this server.",
			},
			{
				Name = "Code",
				Type = "string",
				Description = "The code to load.",
			},
		},
	}, function(_context, userId: number, code: string)
		-- The one command with no offline meaning: an ephemeral slot exists only for the duration of a
		-- live session, so importing one for an absent player would create it and immediately discard it.
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return `{userId} is not in this server, and an ephemeral slot needs a live session.`
		end

		return self:_runLines({ userId }, function(slots, name)
			return slots:PromiseImportEphemeralSaveSlotFromCode(code):Then(function()
				return `Imported ephemeral save slot into {name} from code: {code}`
			end)
		end)
	end)
end

-- SaveSlotService owns the offline entry point. Reached through the module instance rather than by
-- name, because `require("SaveSlotService")` from here is a cyclic module dependency: SaveSlotService
-- registers this service. Mirrors HasSaveSlots._promisePreSelectFromSaveSlotService.
function SaveSlotCmdrService._getSaveSlotService(self: SaveSlotCmdrService): any
	local serviceModule = script.Parent.Parent:FindFirstChild("SaveSlotService")
	if not serviceModule or not self._serviceBag:HasService(serviceModule) then
		return nil
	end

	return self._serviceBag:GetService(serviceModule)
end

-- Resolves a slot index to the target's slot id, including the reserved ephemeral index (see
-- [SaveSlotCmdrUtils]). The index lookup only walks the save list, which an ephemeral slot is excluded
-- from, so that one index resolves against the active slot instead.
function SaveSlotCmdrService._getSlotIdFromIndex(_self: SaveSlotCmdrService, slots: any, slotIndex: number): string?
	if slotIndex == SaveSlotConstants.EPHEMERAL_SLOT_INDEX then
		if slots:IsActiveSlotEphemeral() then
			return slots:GetActiveSlotId()
		end
		return nil
	end

	return slots:GetSlotIdFromIndex(slotIndex)
end

-- Resolves a slotIndices argument (or nil = the active slot) into de-duplicated { slotIndex, slotId }
-- entries. An empty result means nothing matched, and the caller reports it.
function SaveSlotCmdrService._resolveSlotEntries(
	self: SaveSlotCmdrService,
	slots: any,
	slotIndices: { number }?
): SlotEntries
	local entries = {}
	if slotIndices == nil then
		-- The slot they are on, or would resume on. Nothing is ever *selected* in an offline session,
		-- so defaulting to the active slot alone would make every omitted-slot command a no-op there.
		local currentSlotId = slots:GetLastActiveSlotId()
		if not currentSlotId then
			return entries
		end
		local metadata = slots:GetSlotMetadata(currentSlotId)
		if not metadata then
			return entries
		end
		table.insert(entries, { slotIndex = metadata.SlotIndex, slotId = currentSlotId })
	else
		local seen = {}
		for _, slotIndex in slotIndices do
			local slotId = self:_getSlotIdFromIndex(slots, slotIndex)
			if slotId and not seen[slotId] then
				seen[slotId] = true
				table.insert(entries, { slotIndex = slotIndex, slotId = slotId })
			end
		end
	end
	return entries
end

-- Opens a slot system for the target and runs handler against it, whichever realm the target is in:
-- the bound binder's for a player here, a borrowed offline one otherwise. The offline session is
-- always released, including when the handler fails -- holding it would leave the player unable to
-- rejoin.
--
-- Waits for the slots to load first, because the read accessors handler uses are synchronous and see
-- an empty roster until they have.
function SaveSlotCmdrService._promiseWithSlots(
	self: SaveSlotCmdrService,
	userId: number,
	handler: (any, string) -> any
): any
	local player = Players:GetPlayerByUserId(userId)

	if player then
		return self._maid:GivePromise(self._hasSaveSlotsBinder:Promise(player)):Then(function(hasSaveSlots)
			local slots = hasSaveSlots:GetSlotsDataStore()
			return slots:PromiseSlotsLoaded():Then(function()
				return handler(slots, player.Name)
			end)
		end)
	end

	local saveSlotService = self:_getSaveSlotService()
	if not saveSlotService then
		return Promise.rejected("not in this server, and offline save slots are unavailable")
	end

	-- Deliberately not `_maid:GivePromise`, which cancels nothing upstream: on teardown these slots
	-- still resolve, into a continuation the maid has already skipped, and the session they took stays
	-- locked for the rest of the server's life. The maid is probed for liveness instead, and then
	-- handed the slots themselves.
	local probe = {}
	self._maid[probe] = probe

	return saveSlotService:PromiseOfflineSaveSlots(userId):Then(function(offline)
		local isAlive = self._maid[probe] == probe
		self._maid[probe] = nil

		if not isAlive then
			offline:Destroy()
			return Promise.rejected(`Destroyed while opening the save slots for {userId}`)
		end

		local offlineId = self._maid:GiveTask(offline :: any)

		local function release(): any
			self._maid[offlineId] = nil

			-- Destroying only *starts* the borrowed session's save-and-close, so wait for it here: the
			-- command reports success once the lock it took is gone, not while it is still held.
			return self._playerDataStoreService:PromiseSessionClosed(userId)
		end

		return offline
			:PromiseSlotsLoaded()
			:Then(function()
				return handler(offline:GetSlotsDataStore(), tostring(userId))
			end)
			:Then(function(result)
				return release():Then(function()
					return result
				end)
			end, function(err)
				return release():Then(function()
					return Promise.rejected(err)
				end)
			end)
	end, function(err)
		self._maid[probe] = nil
		return Promise.rejected(err)
	end)
end

-- Runs handler once per target, sequentially, to avoid concurrent datastore writes and to keep only
-- one stolen session open at a time. Reports per target, so one failure still surfaces the successes.
function SaveSlotCmdrService._promiseTargetLines(
	self: SaveSlotCmdrService,
	userIds: { number },
	handler: (any, string) -> any
): any
	local promise = Promise.resolved()
	local results: { string } = {}

	for _, userId in userIds do
		promise = promise:Then(function()
			return self:_promiseWithSlots(userId, handler)
				:Then(function(line)
					if line ~= nil then
						table.insert(results, line)
					end
				end)
				:Catch(function(err)
					table.insert(results, `{userId}: {tostring(err)}`)
				end)
		end)
	end

	return promise:Then(function()
		return results
	end)
end

-- Blocking form of _promiseTargetLines, for the command bodies. Cmdr runs commands on their own
-- thread, so yielding here is what lets a command report a finished result.
function SaveSlotCmdrService._runLines(
	self: SaveSlotCmdrService,
	userIds: { number },
	handler: (any, string) -> any
): string
	if #userIds == 0 then
		return "No players to act on."
	end

	local lines = self:_promiseTargetLines(userIds, handler):Wait()
	return table.concat(lines, "\n")
end

-- As _runLines, but resolves each target's slot argument first and runs handleSlot once per matching
-- slot. Reports per slot, so one bad slot does not hide the rest.
function SaveSlotCmdrService._runSlotLines(
	self: SaveSlotCmdrService,
	userIds: { number },
	slotIndices: { number }?,
	handleSlot: (any, SlotEntry, string) -> any
): string
	return self:_runLines(userIds, function(slots, name)
		local entries = self:_resolveSlotEntries(slots, slotIndices)
		if #entries == 0 then
			return `{name}: no matching slots.`
		end

		local lines: { string } = {}
		local promise = Promise.resolved()

		for _, entry in entries do
			promise = promise:Then(function()
				return Promise.resolved()
					:Then(function()
						return handleSlot(slots, entry, name)
					end)
					:Then(function(line)
						if line ~= nil then
							table.insert(lines, line)
						end
					end)
					:Catch(function(err)
						table.insert(lines, `{name} slot {entry.slotIndex}: {tostring(err)}`)
					end)
			end)
		end

		return promise:Then(function()
			return table.concat(lines, "\n")
		end)
	end)
end

function SaveSlotCmdrService.Destroy(self: SaveSlotCmdrService): ()
	self._maid:Destroy()
end

return SaveSlotCmdrService
