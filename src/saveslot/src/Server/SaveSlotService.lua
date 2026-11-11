--!strict
--[=[
	@class SaveSlotService
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brio = require("Brio")
local DataStoreStage = require("DataStoreStage")
local HasSaveSlots = require("HasSaveSlots")
local HasSaveSlotsData = require("HasSaveSlotsData")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local ObservableSet = require("ObservableSet")
local OfflineSaveSlots = require("OfflineSaveSlots")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local Remoting = require("Remoting")
local RxBrioUtils = require("RxBrioUtils")
local SaveSlotCodeUtils = require("SaveSlotCodeUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local SaveSlotExportUtils = require("SaveSlotExportUtils")
local SaveSlotSharedDataStoreService = require("SaveSlotSharedDataStoreService")
local ServiceBag = require("ServiceBag")
local TeleportDataService = require("TeleportDataService")

-- Called with (player, slotId, previousSlotId) before slotId becomes the active slot, while the previous
-- selection is still in place. See RegisterPreSelectCallback.
export type PreSelectCallback = (
	Player,
	SaveSlotData.SlotId,
	SaveSlotData.SlotId?
) -> (Promise.Promise<boolean?> | boolean)?

local SaveSlotService = {}
SaveSlotService.ServiceName = "SaveSlotService"

export type SaveSlotService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_hasSaveSlotsBinder: any,
		_selectionRequired: boolean,
		_maxSlotCount: number,
		_defaultSummaryProviders: ObservableMap.ObservableMap<string, HasSaveSlots.SummaryProvider>,
		-- ObservableSet<PreSelectCallback>; erased because the generic parameterized by a
		-- function type blows up inference.
		_preSelectCallbacks: any,
		_remoting: any,
		_teleportDataService: any,
		_playerDataStoreService: any,
		_sharedSaveSlotDataStoreService: any,
		_codeGenerator: SaveSlotCodeUtils.CodeGenerator?,
	},
	{} :: typeof({ __index = SaveSlotService })
))

function SaveSlotService.Init(self: SaveSlotService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("DataStoreService"))
	self._playerDataStoreService = self._serviceBag:GetService(require("PlayerDataStoreService"))
	self._teleportDataService = self._serviceBag:GetService(TeleportDataService)

	-- Registered here (pre-start) so the HasSaveSlots binder can acquire it when a player binds,
	-- which happens after Start. Mirrors how PlayerDataStoreService/TeleportDataService are pulled in.
	self._sharedSaveSlotDataStoreService = self._serviceBag:GetService(SaveSlotSharedDataStoreService)

	-- Internal
	self._serviceBag:GetService(require("SaveSlotCmdrService"))
	self._serviceBag:GetService(require("SaveSlotDataService"))

	-- Binders
	self._hasSaveSlotsBinder = self._serviceBag:GetService(HasSaveSlots)

	self._selectionRequired = false
	self._maxSlotCount = 1
	self._defaultSummaryProviders = self._maid:Add(ObservableMap.new())
	self._preSelectCallbacks = self._maid:Add(ObservableSet.new())

	self._remoting = self._maid:Add(Remoting.Server.new(ReplicatedStorage, "SaveSlotService"))

	self._maid:GiveTask(self._remoting.GetExplicitSelectionRequired:Bind(function()
		return self:GetExplicitSelectionRequired()
	end))
end

function SaveSlotService.Start(self: SaveSlotService)
	-- Every teleport built through TeleportDataService carries each player's own active slot id, so
	-- cross-place teleports resume on the same slot without each teleport site re-attaching it by hand
	-- (and a group teleport carries every member's slot, not just a single player's).
	self._maid:GiveTask(
		self._teleportDataService:RegisterPerPlayerTeleportDataProvider(function(player: Player): { [string]: any }?
			local slotId = HasSaveSlotsData.ActiveSlotId:Get(player)
			if type(slotId) == "string" then
				return { [SaveSlotConstants.TELEPORT_DATA_SLOT_KEY] = slotId }
			end
			return nil
		end)
	)

	-- A transferable ephemeral slot re-saves its live state and carries its shared-store key across a
	-- teleport. This provider is asynchronous (it persists before returning the key), so it only
	-- contributes through TeleportDataService.PromiseBuildTeleportData; a plain BuildTeleportData drops it.
	self._maid:GiveTask(self._teleportDataService:RegisterPerPlayerTeleportDataProvider(function(player: Player): any
		local hasSaveSlots = self._hasSaveSlotsBinder:Get(player)
		if not hasSaveSlots then
			return nil
		end
		return hasSaveSlots:PromiseBuildEphemeralTransferSlice()
	end))

	self._maid:GiveTask(self._hasSaveSlotsBinder:ObserveAllBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, hasSaveSlots = brio:ToMaidAndValue()

		-- Pass consumer-specified configs
		hasSaveSlots.MaxSlotCount.Value = self._maxSlotCount
		if self._codeGenerator then
			hasSaveSlots:SetCodeGenerator(self._codeGenerator)
		end

		-- Mirror every default summary provider onto this player, and keep it in sync: a provider
		-- registered or unregistered later is added to or removed from every bound player reactively.
		maid:GiveTask(self._defaultSummaryProviders:ObservePairsBrio():Subscribe(function(pairBrio)
			if pairBrio:IsDead() then
				return
			end
			local pairMaid = pairBrio:ToMaid()
			local name, provider = pairBrio:GetValue()
			pairMaid:GiveTask(hasSaveSlots:RegisterSummaryProvider(name, provider))
		end))

		-- Select the slot the player teleported in with, or proceed with the default flow.
		-- The loads can settle long after this player is gone (session-lock or datastore
		-- retries outlive a leave), so the maid must own the INNER promise too, and each
		-- continuation re-checks the binder is alive: a continuation queued before the maid
		-- died still runs, and calling any method on the destroyed (metatable-stripped)
		-- binder throws.
		maid:GivePromise(hasSaveSlots:PromiseSlotsLoaded()):Then(function(): any
			if not hasSaveSlots.Destroy then
				return nil -- The binder died while the load settled
			end
			-- A transferable ephemeral slot carried across a teleport takes precedence over the normal
			-- slot-id resume and the default flow: re-select it from its shared-store key.
			return maid:GivePromise(hasSaveSlots:PromiseLoadTransferableEphemeralSlotFromTeleport())
				:Then(function(ephemeralSlotId): any
					if ephemeralSlotId then
						return nil -- Arrived carrying a transferable ephemeral slot; it is now selected
					end
					if not hasSaveSlots.Destroy then
						return nil
					end
					return maid:GivePromise(hasSaveSlots:PromiseLoadSaveSlotFromTeleport())
						:Then(function(loadedSlotId): any
							if loadedSlotId then
								return nil -- Teleported in with a valid slot; it is now selected
							end
							if not hasSaveSlots.Destroy then
								return nil -- The binder died while the teleport read settled
							end
							return self:_promiseSelectDefaultSlot(maid, hasSaveSlots)
						end)
				end)
		end)
	end))
end

--[=[
	Selects the player's last active slot, or creates and selects the default slot.
	Does nothing when explicit selection is required.

	Every hop is maid-owned and re-checks the binder for the same reason as the caller: any of
	these reads can settle after the player left, and continuing into the destroyed binder throws.
]=]
function SaveSlotService._promiseSelectDefaultSlot(
	self: SaveSlotService,
	maid: any,
	hasSaveSlots: any
): Promise.Promise<any>?
	if self._selectionRequired then
		return nil -- Consumer handles selection
	end

	return maid:GivePromise(hasSaveSlots:PromiseLastActiveSlotId())
		:Then(function(lastActiveSlotId: SaveSlotData.SlotId?): any
			if not hasSaveSlots.Destroy then
				return nil
			end
			return maid:GivePromise(hasSaveSlots:PromiseHasSlot(lastActiveSlotId))
				:Then(function(hasLastSlot: boolean): any
					if not hasSaveSlots.Destroy then
						return nil
					end
					if hasLastSlot then
						return hasSaveSlots:PromiseSelectSlot(lastActiveSlotId)
					end

					-- Or create and select default slot
					return maid:GivePromise(hasSaveSlots:PromiseSlotIdFromIndex(SaveSlotConstants.DEFAULT_SLOT_INDEX))
						:Then(function(defaultSlotId: SaveSlotData.SlotId?): any
							if not hasSaveSlots.Destroy then
								return nil
							end
							if defaultSlotId then
								return defaultSlotId
							else
								return hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX)
							end
						end)
						:Then(function(slotId: SaveSlotData.SlotId?): any
							if not slotId or not hasSaveSlots.Destroy then
								return nil
							end
							return hasSaveSlots:PromiseSelectSlot(slotId)
						end)
				end)
		end)
end

--[=[
	Requires explicit slot selection
]=]
function SaveSlotService.RequireExplicitSelection(self: SaveSlotService): ()
	assert(not self._serviceBag:IsStarted(), "RequireExplicitSelection must be called before Start")
	self._selectionRequired = true
end

--[=[
	Returns whether explicit slot selection is required
]=]
function SaveSlotService.GetExplicitSelectionRequired(self: SaveSlotService): boolean
	return self._selectionRequired
end

--[=[
	Resolves whether the player teleported in carrying a save-slot id -- i.e. arrived via an internal
	slot teleport rather than a fresh join. Presence-only (it does not validate the slot still exists);
	use [HasSaveSlots.PromiseHasSaveSlotFromTeleport] when existence matters. It is a promise because a
	client-initiated teleport only reaches the server once the client replicates its arrived data.

	@param player Player
	@return Promise<boolean>
]=]
function SaveSlotService.PromiseIsInternalTeleport(self: SaveSlotService, player: Player): Promise.Promise<boolean>
	return self._teleportDataService:PromiseHasArrivedValue(player, SaveSlotConstants.TELEPORT_DATA_SLOT_KEY)
end

--[=[
	Sets the max slot count
]=]
function SaveSlotService.SetMaxSlotCount(self: SaveSlotService, maxSlotCount: number): ()
	assert(not self._serviceBag:IsStarted(), "SetMaxSlotCount must be called before Start")
	assert(maxSlotCount >= 1, "Bad maxSlotCount")
	self._maxSlotCount = maxSlotCount
end

--[=[
	Removes the slot ceiling, so [HasSaveSlots.PromiseSelectNewSaveSlot] always
	allocates the next free index. A thin alias over [SaveSlotService.SetMaxSlotCount]
	with an unbounded count; same before-Start guard applies.
]=]
function SaveSlotService.SetUnlimitedSlots(self: SaveSlotService): ()
	self:SetMaxSlotCount(math.huge)
end

--[=[
	Opens the save slots of a player who is **not in this server**, as an [OfflineSaveSlots] the caller
	must destroy. The game's slot count and code generator are applied, so an offline edit behaves like
	an online one.

	:::warning
	This steals the player's session lock, kicking them from wherever they are playing, and holds it
	until the returned object is destroyed. It backs admin tooling ([SaveSlotCmdrService]); it is not
	something to reach for on a normal code path.
	:::

	Rejects for a player who *is* in this server: they already have a live [HasSaveSlots] holding their
	session, and a second copy of their data would be written from underneath it. Use the binder.

	@param userId number
	@return Promise<OfflineSaveSlots>
]=]
function SaveSlotService.PromiseOfflineSaveSlots(
	self: SaveSlotService,
	userId: number
): Promise.Promise<OfflineSaveSlots.OfflineSaveSlots>
	assert(type(userId) == "number", "Bad userId")

	if Players:GetPlayerByUserId(userId) then
		return Promise.rejected(`{userId} is in this server -- use their HasSaveSlots binder`)
	end

	-- Deliberately not `_maid:GivePromise`, which cancels nothing upstream: on teardown the handle
	-- still resolves, into a continuation the maid has already skipped, and the session it took stays
	-- locked for the rest of the server's life. The maid is probed for liveness instead, so a handle
	-- that arrives too late is handed straight back rather than orphaned.
	local probe = {}
	self._maid[probe] = probe

	return self._playerDataStoreService:PromiseDataStoreHandle(userId):Then(function(handle)
		local isAlive = self._maid[probe] == probe
		self._maid[probe] = nil

		if not isAlive then
			handle:Destroy()
			-- Cast because this branch makes the callback return a union with the slots below, which
			-- the solver otherwise tries to unify into one type.
			return (Promise :: any).rejected(`Destroyed while opening the datastore for {userId}`)
		end

		return OfflineSaveSlots.new(handle, {
			SharedDataStoreService = self._sharedSaveSlotDataStoreService,
			MaxSlotCount = self._maxSlotCount,
			CodeGenerator = self._codeGenerator,
			UserId = userId,
		})
	end, function(err)
		self._maid[probe] = nil
		return Promise.rejected(err)
	end)
end

--[=[
	Sets the share-code generator applied to every player's exports (see [SaveSlotCodeUtils.CodeGenerator]),
	so a game can choose a code format that suits its players. Defaults to
	[SaveSlotCodeUtils.generateDefaultCode]. Must be called before Start.

	@param generator SaveSlotCodeUtils.CodeGenerator
]=]
function SaveSlotService.SetCodeGenerator(self: SaveSlotService, generator: SaveSlotCodeUtils.CodeGenerator): ()
	assert(not self._serviceBag:IsStarted(), "SetCodeGenerator must be called before Start")
	assert(type(generator) == "function", "Bad generator")
	self._codeGenerator = generator
end

--[=[
	Registers a named default summary provider, applied to every player's save slots. Each provider's
	current value is aggregated into the active slot's Summary, keyed by `name`. Registering or
	unregistering reflects on all bound players. Returns a function that unregisters the provider (also
	give it to a [Maid]).

	@param name string
	@param provider HasSaveSlots.SummaryProvider
	@return () -> ()
]=]
function SaveSlotService.RegisterDefaultSummaryProvider(
	self: SaveSlotService,
	name: string,
	provider: HasSaveSlots.SummaryProvider
): () -> ()
	assert(type(name) == "string", "Bad name")
	assert(type(provider) == "function", "Bad provider")

	return self._defaultSummaryProviders:Set(name, provider :: any)
end

--[=[
	Registers a callback to run for every player immediately before a slot becomes active, whatever
	selected it. It runs with the previous selection still in place, and what it returns decides what
	happens next:

	* nothing (or `true`) -- allow the selection
	* `false` -- refuse it; the selection rejects and the active slot is left alone
	* a promise -- hold the selection open until it settles, refusing if it resolves `false`

	An error or a rejection is warned about and allows the selection: only a stated `false` refuses. There
	is no timeout, so keep the work bounded.

	@param callback PreSelectCallback
	@return () -> () -- Removes the callback
]=]
function SaveSlotService.RegisterPreSelectCallback(self: SaveSlotService, callback: PreSelectCallback): () -> ()
	assert(type(callback) == "function", "Bad callback")

	return self._preSelectCallbacks:Add(callback)
end

--[=[
	Runs every registered pre-select callback for a slot about to become active, resolving with whether the
	selection may proceed once the ones that returned a promise have settled. Called by [HasSaveSlots] as
	each selection commits.

	Every callback runs, even once one has refused: they are independent, and one that only wanted to
	settle state must not be skipped because an unrelated one said no.

	@param player Player
	@param slotId SlotId
	@param previousSlotId SlotId?
	@return Promise<boolean> -- False when any callback refused
]=]
function SaveSlotService.PromisePreSelect(
	self: SaveSlotService,
	player: Player,
	slotId: SaveSlotData.SlotId,
	previousSlotId: SaveSlotData.SlotId?
): Promise.Promise<boolean>
	local promises = {}
	local refused = false

	for _, callback in self._preSelectCallbacks:GetList() do
		local ok, result = pcall(callback, player, slotId, previousSlotId)
		if not ok then
			warn(`[SaveSlotService] - Pre-select callback errored: {tostring(result)}`)
		elseif Promise.isPromise(result) then
			table.insert(
				promises,
				(result :: any):Then(function(allowed: boolean?)
					if allowed == false then
						refused = true
					end
				end, function(err: any)
					warn(`[SaveSlotService] - Pre-select callback rejected: {tostring(err)}`)
				end)
			)
		elseif result == false then
			refused = true
		end
	end

	return (PromiseUtils.all(promises) :: any):Then(function()
		return not refused
	end)
end

--[=[
	Observes the [DataStoreStage] for the player's active slot as a [Brio]
]=]
function SaveSlotService.ObserveActiveSlotStoreBrio(
	self: SaveSlotService,
	player: Player
): Observable.Observable<Brio.Brio<DataStoreStage.DataStoreStage>>
	return self._hasSaveSlotsBinder:ObserveBrio(player):Pipe({
		RxBrioUtils.switchMapBrio(function(hasSaveSlots)
			return hasSaveSlots:ObserveActiveSlotStoreBrio()
		end),
	})
end

--[=[
	Returns the [DataStoreStage] for the player's active slot
]=]
function SaveSlotService.PromiseActiveSlotStore(
	self: SaveSlotService,
	player: Player
): Promise.Promise<DataStoreStage.DataStoreStage?>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseActiveSlotStore()
	end)
end

--[=[
	Returns whether the player has a slot with the given ID
]=]
function SaveSlotService.PromiseHasSlot(
	self: SaveSlotService,
	player: Player,
	slotId: SaveSlotData.SlotId
): Promise.Promise<boolean>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseHasSlot(slotId)
	end)
end

--[=[
	Selects the slot with the given ID for the player
]=]
function SaveSlotService.PromiseSelectSlot(
	self: SaveSlotService,
	player: Player,
	slotId: SaveSlotData.SlotId
): Promise.Promise<DataStoreStage.DataStoreStage>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseSelectSlot(slotId)
	end)
end

--[=[
	Creates a slot for the player at the given index
]=]
function SaveSlotService.PromiseCreateSlot(
	self: SaveSlotService,
	player: Player,
	slotIndex: number,
	metadata: SaveSlotData.SaveSlotMetadata?
): Promise.Promise<any>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseCreateSlot(slotIndex, metadata)
	end)
end

--[=[
	Deletes the slot with the given ID for the player
]=]
function SaveSlotService.PromiseDeleteSlot(
	self: SaveSlotService,
	player: Player,
	slotId: SaveSlotData.SlotId
): Promise.Promise<any>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseDeleteSlot(slotId)
	end)
end

--[=[
	Resets the player's active slot to a fresh empty one
]=]
function SaveSlotService.PromiseResetActiveSlot(self: SaveSlotService, player: Player): Promise.Promise<any>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseResetActiveSlot()
	end)
end

--[=[
	Turns the player's ephemeral session into a real save slot and continues play on it, resolving to the
	new slot id. See [HasSaveSlots.PromisePersistEphemeralSlot].
]=]
function SaveSlotService.PromisePersistEphemeralSlot(
	self: SaveSlotService,
	player: Player,
	slotId: SaveSlotData.SlotId?
): Promise.Promise<SaveSlotData.SlotId>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromisePersistEphemeralSlot(slotId)
	end)
end

--[=[
	Exports the player's non-main slot into a serializable table. See [HasSaveSlots.PromiseExportSlot].
]=]
function SaveSlotService.PromiseExportSlot(
	self: SaveSlotService,
	player: Player,
	slotId: SaveSlotData.SlotId
): Promise.Promise<SaveSlotExportUtils.SaveSlotExport>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseExportSlot(slotId)
	end)
end

--[=[
	Imports an exported slot into a fresh non-main slot for the player, resolving to the new slot id.
	See [HasSaveSlots.PromiseImportSlot].
]=]
function SaveSlotService.PromiseImportSlot(
	self: SaveSlotService,
	player: Player,
	export: SaveSlotExportUtils.SaveSlotExport
): Promise.Promise<SaveSlotData.SlotId>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseImportSlot(export)
	end)
end

--[=[
	Saves the player's non-main slot to the shared store under the given key. See
	[HasSaveSlots.PromiseSaveSlotToSharedDataStore].
]=]
function SaveSlotService.PromiseSaveSlotToSharedDataStore(
	self: SaveSlotService,
	player: Player,
	slotId: SaveSlotData.SlotId,
	key: string
): Promise.Promise<boolean>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseSaveSlotToSharedDataStore(slotId, key)
	end)
end

--[=[
	Imports a shared-store export into a fresh non-main slot for the player. See
	[HasSaveSlots.PromiseImportSlotFromSharedDataStore].
]=]
function SaveSlotService.PromiseImportSlotFromSharedDataStore(
	self: SaveSlotService,
	player: Player,
	key: string
): Promise.Promise<SaveSlotData.SlotId>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseImportSlotFromSharedDataStore(key)
	end)
end

--[=[
	Exports the player's slot to the shared store under a fresh code and resolves to it. See
	[HasSaveSlots.PromiseExportSaveSlotToCode].
]=]
function SaveSlotService.PromiseExportSaveSlotToCode(
	self: SaveSlotService,
	player: Player,
	slotId: SaveSlotData.SlotId?
): Promise.Promise<string>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseExportSaveSlotToCode(slotId)
	end)
end

--[=[
	Loads the code into a fresh transferable ephemeral slot for the player. See
	[HasSaveSlots.PromiseImportEphemeralSaveSlotFromCode].
]=]
function SaveSlotService.PromiseImportEphemeralSaveSlotFromCode(
	self: SaveSlotService,
	player: Player,
	code: string
): Promise.Promise<SaveSlotData.SlotId>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseImportEphemeralSaveSlotFromCode(code)
	end)
end

--[=[
	Exports the player's slot as a raw JSON string. See [HasSaveSlots.PromiseExportSaveSlotToJson].
]=]
function SaveSlotService.PromiseExportSaveSlotToJson(
	self: SaveSlotService,
	player: Player,
	slotId: SaveSlotData.SlotId?
): Promise.Promise<string>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseExportSaveSlotToJson(slotId)
	end)
end

--[=[
	Destroys the service
]=]
function SaveSlotService.Destroy(self: SaveSlotService): ()
	self._maid:Destroy()
end

return SaveSlotService
