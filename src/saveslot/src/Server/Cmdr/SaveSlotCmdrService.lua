--!strict
--[=[
	Save slot admin commands.

	| Command | What it does |
	| --- | --- |
	| `saveslot-list` | Lists every slot with its playtime, timestamps and summary |
	| `saveslot-get-active` | Reports the slot being played, or the one that would resume |
	| `saveslot-select` | Switches onto a slot |
	| `saveslot-deselect` | Returns to the no-slot state |
	| `saveslot-create` | Creates slots, defaulting to the lowest free index |
	| `saveslot-delete` | Deletes slots |
	| `saveslot-copy` | Copies one player's slot onto other players', **overwriting an occupied destination** |
	| `saveslot-persist` | Turns the ephemeral session into a save and switches onto it |
	| `saveslot-reset` | Empties slots, keeping their index and name |
	| `saveslot-export` / `saveslot-import` | Moves a slot through the shared store as a code |
	| `saveslot-read-json` / `saveslot-write-json` | Moves a slot as raw JSON, no shared store |
	| `saveslot-import-ephemeral` | Loads a code into a throwaway session |

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

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local CmdrReplyUtils = require("CmdrReplyUtils")
local CmdrService = require("CmdrService")
local CmdrTypes = require("CmdrTypes")
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
type CommandContext = CmdrTypes.CommandContext

export type SaveSlotCmdrService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrService: any,
		_hasSaveSlotsBinder: any,
		_playerDataStoreService: any,
		_saveSlotDataService: any,
		_replyConfig: CmdrReplyUtils.CmdrReplyConfig,
	},
	{} :: typeof({ __index = SaveSlotCmdrService })
))

function SaveSlotCmdrService.Init(self: SaveSlotCmdrService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
	self._replyConfig = CmdrReplyUtils.createConfig()

	-- External
	self._cmdrService = self._serviceBag:GetService(CmdrService)
	self._playerDataStoreService = self._serviceBag:GetService(PlayerDataStoreService)

	-- Internal
	self._hasSaveSlotsBinder = self._serviceBag:GetService(HasSaveSlots)
	self._saveSlotDataService = self._serviceBag:GetService(SaveSlotDataService)
end

--[=[
	Sets how long a command may run before it tells the executor it is still working, and how that
	line is colored.

	@param replyConfig CmdrReplyConfig -- see [CmdrReplyUtils.createConfig]
]=]
function SaveSlotCmdrService.SetReplyConfig(self: SaveSlotCmdrService, replyConfig: CmdrReplyUtils.CmdrReplyConfig): ()
	assert(CmdrReplyUtils.isCmdrReplyConfig(replyConfig), "Bad replyConfig")

	self._replyConfig = replyConfig
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
		Name = "saveslot-list",
		Description = "Lists all save slots.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
		},
	}, function(context: CommandContext, userIds: { number })
		return self:_runLines(context, userIds, function(slots, name)
			local activeSlotId = slots:GetActiveSlotId()

			local blocks = {}
			for _, metadata in slots:GetSlotList() do
				local status = if metadata.SlotId == activeSlotId then "Active" else nil
				table.insert(blocks, SaveSlotCmdrUtils.formatSlotBlock(metadata, status))
			end

			-- An ephemeral session is not a save, so it is absent from the slot list above -- but it is what
			-- the player is playing right now and the thing saveslot-persist acts on, so list it under the
			-- reserved index the other commands address it by.
			if slots:IsActiveSlotEphemeral() then
				table.insert(
					blocks,
					SaveSlotCmdrUtils.formatSlotBlock(slots:GetActiveSlotMetadata(), "Active, ephemeral")
				)
			end

			if #blocks == 0 then
				return `\n{name}:\nNo slots.`
			end

			return `\n{name}:\n\n{table.concat(blocks, "\n\n")}`
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "saveslot-get-active",
		Description = "Returns the active save slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
		},
	}, function(context: CommandContext, userIds: { number })
		return self:_runLines(context, userIds, function(slots, name)
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
		Name = "saveslot-select",
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
	}, function(context: CommandContext, userIds: { number }, slotIndex: number)
		return self:_runLines(context, userIds, function(slots, name)
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
		Name = "saveslot-deselect",
		Description = "Clears the active save slot, returning to a no-slot state.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
		},
	}, function(context: CommandContext, userIds: { number })
		return self:_runLines(context, userIds, function(slots, name)
			if not slots:GetActiveSlotId() then
				return `{name} has no active slot.`
			end

			return slots:PromiseDeselectSlot():Then(function()
				return `{name} deselected active slot.`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "saveslot-create",
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
	}, function(context: CommandContext, userIds: { number }, slotIndices: { number }?)
		return self:_runLines(context, userIds, function(slots, name)
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
		Name = "saveslot-delete",
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
	}, function(context: CommandContext, userIds: { number }, slotIndices: { number })
		return self:_runSlotLines(context, userIds, slotIndices, function(slots, entry, name)
			return self:_promiseClearSlot(slots, entry.slotId):Then(function()
				return `{name} deleted slot {entry.slotIndex}.`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand(
		{
			Name = "saveslot-copy",
			Description = "Copies one player's save slot onto other players' slots. Defaults to the lowest free index when no destination is given, and OVERWRITES the destination slot when one already exists there. Copying an ephemeral session saves it without switching onto the copy -- see saveslot-persist.",
			Group = "SaveSlots",
			Args = {
				{
					Name = "FromPlayer",
					Type = "playerId",
					Description = "Player to copy from (e.g. . for yourself, a username, or #userId). A player who is not in this server is read offline, which kicks them.",
				},
				{
					Name = "FromSlot",
					Type = "slotIndex",
					Description = "Slot index to copy from, or . for your current slot.",
				},
				{
					Name = "ToPlayers",
					Type = "playerIds",
					Description = PLAYERS_ARG_DESCRIPTION,
				},
				{
					Name = "ToSlot",
					Type = "slotIndex",
					Description = "Slot index to copy onto. Omit for the lowest free index. An existing slot there is deleted first.",
					Optional = true,
				},
			},
		},
		function(
			context: CommandContext,
			fromUserId: number,
			fromSlotIndex: number,
			toUserIds: { number },
			toSlotIndex: number?
		)
			-- Rejected once for the whole command rather than per target, since neither destination depends
			-- on who is being written to. An ephemeral session exists only while it is active, so it can be
			-- a source (that is how a session becomes a save) but never a destination. The main slot is
			-- refused because its store is the player's shared root: an import there would land on top of
			-- their universe-wide data (see HasSaveSlotsDataStore.PromiseImportSlot).
			if toSlotIndex == SaveSlotConstants.EPHEMERAL_SLOT_INDEX then
				return "An ephemeral session cannot be copied onto."
			elseif toSlotIndex == SaveSlotConstants.DEFAULT_SLOT_INDEX then
				return `The main slot ({SaveSlotConstants.DEFAULT_SLOT_INDEX}) cannot be copied onto.`
			end

			-- Read the source once, up front, and give its session back before any destination is opened:
			-- the source player may also be a destination, and a second session on the same player would be
			-- racing the first for their own lock. Mirrors datastore-copy.
			local readPromise = self:_promiseWithSlots(fromUserId, function(slots, name)
				local sourceSlotId = self:_getSlotIdFromIndex(slots, fromSlotIndex)
				if not sourceSlotId then
					return Promise.rejected(`{name} has no slot with index {fromSlotIndex}`)
				end

				-- Admin tooling copies the main slot too, which the normal path refuses. See
				-- HasSaveSlotsDataStore.PromiseExportSlot for what that carries.
				return slots:PromiseExportSlot(sourceSlotId, true):Then(function(export)
					return { export = export, slotId = sourceSlotId, name = name }
				end)
			end)

			local ok, source = CmdrReplyUtils.replyWhenSlow(
				self._replyConfig,
				context,
				self._maid:GivePromise(readPromise),
				`{fromUserId}: still reading...`
			):Yield()
			if not ok then
				return `Failed to read {fromUserId}: {tostring(source)}`
			end

			return self:_runLines(context, toUserIds, function(slots, name, userId)
				local existingSlotId = if toSlotIndex then slots:GetSlotIdFromIndex(toSlotIndex) else nil
				if (userId == fromUserId) and (existingSlotId == source.slotId) then
					return `{name}: slot {fromSlotIndex} is both the source and the destination.`
				end

				-- Within one roster the copy would otherwise sit beside the original under its name, so it
				-- is suffixed the way a duplicate always was. Across players it keeps the name it had.
				local export = source.export
				if (userId == fromUserId) and export.slotName then
					export = table.clone(export)
					export.slotName = `{export.slotName} (Copy)`
				end

				local clear = if existingSlotId
					then self:_promiseClearSlot(slots, existingSlotId)
					else Promise.resolved()

				return clear
					:Then(function()
						return slots:PromiseImportSlot(export, toSlotIndex)
					end)
					:Then(function(newSlotId)
						local newMetadata = slots:GetSlotMetadata(newSlotId)
						local overwrote = if existingSlotId then ", overwriting what was there" else ""
						return `Copied {source.name} slot {fromSlotIndex} → {name} slot {newMetadata.SlotIndex} ("{newMetadata.SlotName}"){overwrote}`
					end)
			end)
		end
	)

	self._cmdrService:RegisterCommand({
		Name = "saveslot-persist",
		Description = "Turns an ephemeral session into a real save slot and switches onto it.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
		},
	}, function(context: CommandContext, userIds: { number })
		-- Takes no slot argument: an ephemeral slot exists only while it is active, so the active slot is
		-- the only one there is to persist. An absent player has no session at all, so this only ever
		-- reports on them.
		return self:_runLines(context, userIds, function(slots, name)
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
		Name = "saveslot-reset",
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
				-- optional Slots would leave `saveslot-reset *` as valid syntax that wipes the active
				-- slot of every player in the server.
				Name = "Slots",
				Type = "slotIndices",
				Description = "Slot indices to reset (e.g. 1,2, . for your current slot, or * for all).",
			},
		},
	}, function(context: CommandContext, userIds: { number }, slotIndices: { number })
		return self:_runSlotLines(context, userIds, slotIndices, function(slots, entry, name)
			return slots:PromiseResetSlot(entry.slotId):Then(function()
				return `{name} reset slot {entry.slotIndex}.`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "saveslot-export",
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
	}, function(context: CommandContext, userIds: { number }, slotIndices: { number }?)
		-- Admin tooling exports the main slot too, which the normal path refuses. See
		-- HasSaveSlotsDataStore.PromiseExportSlot for what that carries.
		return self:_runSlotLines(context, userIds, slotIndices, function(slots, entry, name)
			return slots:PromiseExportSaveSlotToCode(entry.slotId, true):Then(function(code)
				return `{name} slot {entry.slotIndex} → {code}`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "saveslot-read-json",
		Description = "Reads save slots as raw JSON (no shared store) and prints them.",
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
				Description = "Slot indices to read (e.g. 1,2, . for your current slot, or * for all). Omit for each player's active slot.",
				Optional = true,
			},
		},
	}, function(context: CommandContext, userIds: { number }, slotIndices: { number }?)
		-- Admin tooling reads the main slot too, which the normal path refuses. See
		-- HasSaveSlotsDataStore.PromiseExportSlot for what that carries.
		return self:_runSlotLines(context, userIds, slotIndices, function(slots, entry, name)
			return slots:PromiseExportSaveSlotToJson(entry.slotId, true):Then(function(json)
				return `-- {name} slot {entry.slotIndex}\n{json}`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "saveslot-write-json",
		Description = "Writes raw JSON (as printed by saveslot-read-json) into a save slot. Defaults to the lowest free index when no destination is given, and OVERWRITES the destination slot when one already exists there.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Players",
				Type = "playerIds",
				Description = PLAYERS_ARG_DESCRIPTION,
			},
			-- Ahead of the optional slot, since Cmdr can only leave trailing arguments off.
			{
				Name = "Json",
				Type = "string",
				Description = "Save slot JSON to write.",
			},
			{
				Name = "ToSlot",
				Type = "slotIndex",
				Description = "Slot index to write onto. Omit for the lowest free index. An existing slot there is deleted first.",
				Optional = true,
			},
		},
	}, function(context: CommandContext, userIds: { number }, json: string, toSlotIndex: number?)
		-- Decoded once, up front: a malformed argument is the whole command's problem, not something to
		-- discover separately against each target after stealing their session.
		local ok, export = pcall(HttpService.JSONDecode, HttpService, json)
		if not ok then
			return `Failed: could not decode JSON: {tostring(export)}`
		end

		-- Refused for the same reasons saveslot-copy refuses them, and likewise once for the whole command.
		if toSlotIndex == SaveSlotConstants.EPHEMERAL_SLOT_INDEX then
			return "An ephemeral session cannot be written onto."
		elseif toSlotIndex == SaveSlotConstants.DEFAULT_SLOT_INDEX then
			return `The main slot ({SaveSlotConstants.DEFAULT_SLOT_INDEX}) cannot be written onto.`
		end

		return self:_runLines(context, userIds, function(slots, name)
			local existingSlotId = if toSlotIndex then slots:GetSlotIdFromIndex(toSlotIndex) else nil
			local clear = if existingSlotId then self:_promiseClearSlot(slots, existingSlotId) else Promise.resolved()

			return clear
				:Then(function()
					return slots:PromiseImportSlot(export, toSlotIndex)
				end)
				:Then(function(newSlotId)
					local metadata = slots:GetSlotMetadata(newSlotId)
					local overwrote = if existingSlotId then ", overwriting what was there" else ""
					return `{name} wrote JSON → slot {metadata.SlotIndex} ("{metadata.SlotName}"){overwrote}`
				end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "saveslot-import",
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
	}, function(context: CommandContext, userId: number, code: string)
		return self:_runLines(context, { userId }, function(slots, name)
			return slots:PromiseImportSlotFromSharedDataStore(code):Then(function(newSlotId)
				local metadata = slots:GetSlotMetadata(newSlotId)
				return `Imported save slot from code into {name} slot {metadata.SlotIndex} ("{metadata.SlotName}").`
			end)
		end)
	end)

	self._cmdrService:RegisterCommand({
		Name = "saveslot-import-ephemeral",
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
	}, function(context: CommandContext, userId: number, code: string)
		-- The one command with no offline meaning: an ephemeral slot exists only for the duration of a
		-- live session, so importing one for an absent player would create it and immediately discard it.
		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return `{userId} is not in this server, and an ephemeral slot needs a live session.`
		end

		return self:_runLines(context, { userId }, function(slots, name)
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

-- Deletes a slot, handling the case where it is the one being played. Backs saveslot-delete, and the
-- overwriting half of saveslot-copy and saveslot-write-json, which make room by deleting first.
--
-- The active slot can't be deleted while selected, so deselect it first (flushing its progress) when
-- reached. Read live rather than up front, since an earlier deletion in the same batch may have
-- already deselected it. An ephemeral session is left alone: PromiseDeleteSlot retires it itself, and
-- deselecting first would retire it early, leaving nothing behind to delete.
function SaveSlotCmdrService._promiseClearSlot(_self: SaveSlotCmdrService, slots: any, slotId: string): any
	local isActive = (slotId == slots:GetActiveSlotId())
	local deselect = if isActive and not slots:IsActiveSlotEphemeral()
		then slots:PromiseDeselectSlot()
		else Promise.resolved()

	return deselect:Then(function()
		return slots:PromiseDeleteSlot(slotId)
	end)
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
	handler: (any, string, number) -> any
): any
	local player = Players:GetPlayerByUserId(userId)

	if player then
		return self._maid:GivePromise(self._hasSaveSlotsBinder:Promise(player)):Then(function(hasSaveSlots)
			local slots = hasSaveSlots:GetSlotsDataStore()
			return slots:PromiseSlotsLoaded():Then(function()
				return handler(slots, player.Name, userId)
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
				return handler(offline:GetSlotsDataStore(), tostring(userId), userId)
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
--
-- Nothing reaches the console until every target is done, and opening an absent player's session can
-- take a while, so a target still going after the reply config's slowReplySeconds says so.
function SaveSlotCmdrService._promiseTargetLines(
	self: SaveSlotCmdrService,
	context: CommandContext,
	userIds: { number },
	handler: (any, string, number) -> any
): any
	local promise = Promise.resolved()
	local results: { string } = {}

	for _, userId in userIds do
		promise = promise:Then(function()
			return CmdrReplyUtils.replyWhenSlow(
				self._replyConfig,
				context,
				self:_promiseWithSlots(userId, handler),
				`{userId}: still working...`
			)
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
	context: CommandContext,
	userIds: { number },
	handler: (any, string, number) -> any
): string
	if #userIds == 0 then
		return "No players to act on."
	end

	local lines = self:_promiseTargetLines(context, userIds, handler):Wait()
	return table.concat(lines, "\n")
end

-- As _runLines, but resolves each target's slot argument first and runs handleSlot once per matching
-- slot. Reports per slot, so one bad slot does not hide the rest.
function SaveSlotCmdrService._runSlotLines(
	self: SaveSlotCmdrService,
	context: CommandContext,
	userIds: { number },
	slotIndices: { number }?,
	handleSlot: (any, SlotEntry, string) -> any
): string
	return self:_runLines(context, userIds, function(slots, name)
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
