--!strict
--[=[
	Binds the save slot system to a live [Player].

	The slot model itself -- the roster, per-slot stores, selection, create/delete/reset,
	export/import, ephemeral slots and playtime -- lives in [HasSaveSlotsDataStore], built here over
	the player's datastore. What stays behind is everything that only means something for a player in
	this server: replicating the slot container under them, the client remotes, teleport data, and
	summary providers (which are handed the [Player]).

	Every slot method below is a straight delegation. Reach for [HasSaveSlotsDataStore] directly only
	when there is no player to bind -- admin tooling acting on someone who is not in this server.

	@class HasSaveSlots
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Brio = require("Brio")
local DataStoreStage = require("DataStoreStage")
local HasSaveSlotsBase = require("HasSaveSlotsBase")
local HasSaveSlotsDataStore = require("HasSaveSlotsDataStore")
local HasSaveSlotsInterface = require("HasSaveSlotsInterface")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local PlayerBinder = require("PlayerBinder")
local PlayerDataStoreService = require("PlayerDataStoreService")
local Promise = require("Promise")
local Remoting = require("Remoting")
local Rx = require("Rx")
local SaveSlotCodeUtils = require("SaveSlotCodeUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local SaveSlotExportUtils = require("SaveSlotExportUtils")
local SaveSlotSharedDataStoreService = require("SaveSlotSharedDataStoreService")
local ServiceBag = require("ServiceBag")
local Signal = require("Signal")
local TeleportDataService = require("TeleportDataService")
local ValueObject = require("ValueObject")

-- A summary provider contributes one named piece of a slot's Summary. It is called with the player and
-- the slot's DataStoreStage and returns an Observable of a JSON-serializable value. Providers are
-- aggregated into a table keyed by their registered name; see RegisterSummaryProvider and _setupSummary.
export type SummaryProvider = (Player, DataStoreStage.DataStoreStage) -> Observable.Observable<any>

-- Re-exported so consumers keep naming this through HasSaveSlots; see HasSaveSlotsDataStore.
export type SaveSlotCreateMetadata = HasSaveSlotsDataStore.SaveSlotCreateMetadata

-- A provider that errors (when called, or mid-stream) contributes this sentinel rather than stalling or
-- failing the whole aggregate; _setupSummary strips it back out before writing the Summary. Compared by
-- identity, so it never collides with a real value (even an empty table) a provider might emit.
local NONE = {}

local HasSaveSlots = {}
HasSaveSlots.ClassName = "HasSaveSlots"
HasSaveSlots.__index = HasSaveSlots
-- Runtime inheritance only. Typing the metatable target as `any` keeps the old solver from chasing
-- the full HasSaveSlotsBase type here, which -- now that this class also names HasSaveSlotsDataStore
-- across every delegation -- overflows its complexity budget ("Code is too complex"). The inherited
-- surface is supplied structurally below.
setmetatable(HasSaveSlots :: any, HasSaveSlotsBase)

-- Minimal structural surface inherited from HasSaveSlotsBase, for this class and its consumers. See
-- the setmetatable note above for why we don't intersect HasSaveSlotsBase.HasSaveSlotsBase.
type HasSaveSlotsBaseLike = {
	_obj: Player,
	_maid: Maid.Maid,

	ActiveSlotId: ValueObject.ValueObject<SaveSlotData.SlotId?>,
	LastActiveSlotId: ValueObject.ValueObject<SaveSlotData.SlotId?>,
	ActiveTransferableEphemeralKey: ValueObject.ValueObject<string?>,
	MaxSlotCount: ValueObject.ValueObject<number>,
	SlotChanged: Signal.Signal<SaveSlotData.SlotId>,

	PromiseHasSaveSlotFromTeleport: (self: any) -> Promise.Promise<boolean>,
	PromiseLoadSaveSlotFromTeleport: (self: any) -> Promise.Promise<SaveSlotData.SlotId?>,
	Destroy: (self: any) -> (),
}

export type HasSaveSlots =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_playerDataStoreService: any,
			-- A HasSaveSlotsDataStore. Untyped for the reason given on GetSlotsDataStore.
			_slotsDataStore: any,
			_remoting: any,
			_summaryProviders: ObservableMap.ObservableMap<string, SummaryProvider>,
			_teleportDataService: any,
			_sharedSaveSlotDataStoreService: any,
		},
		{} :: typeof({ __index = HasSaveSlots })
	))
	& HasSaveSlotsBaseLike

function HasSaveSlots.new(player: Player, serviceBag: ServiceBag.ServiceBag): HasSaveSlots
	local self: HasSaveSlots = setmetatable(HasSaveSlotsBase.new(player, serviceBag) :: any, HasSaveSlots)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._playerDataStoreService = self._serviceBag:GetService(PlayerDataStoreService)
	self._teleportDataService = self._serviceBag:GetService(TeleportDataService)
	self._sharedSaveSlotDataStoreService = self._serviceBag:GetService(SaveSlotSharedDataStoreService)

	self._summaryProviders = self._maid:Add(ObservableMap.new())

	-- UserId is read defensively because it is not indexable on every stand-in a binder can be bound to.
	local okUserId, userId = pcall(function()
		return self._obj.UserId
	end)

	-- Annotated rather than inlined into the call: inferring this table against the class's
	-- intersection type tips luau-lsp into "Code is too complex to typecheck".
	local options: HasSaveSlotsDataStore.HasSaveSlotsDataStoreOptions = {
		ActiveSlotId = self.ActiveSlotId,
		LastActiveSlotId = self.LastActiveSlotId,
		ActiveTransferableEphemeralKey = self.ActiveTransferableEphemeralKey,
		MaxSlotCount = self.MaxSlotCount,
		SharedDataStoreService = self._sharedSaveSlotDataStoreService,
		PromisePreSelect = function(slotId: SaveSlotData.SlotId)
			return self:_promisePreSelectFromSaveSlotService(slotId)
		end,
		UserId = if okUserId and type(userId) == "number" then userId else nil,
		UserName = self._obj.Name,
		TrackPlaytime = true,
	}

	self._slotsDataStore =
		self._maid:Add(HasSaveSlotsDataStore.new(self._playerDataStoreService:PromiseDataStore(self._obj), options))

	-- Replicate the slot roster from the player, which is where the client reads it (see
	-- SaveSlotDataService). The slot system itself has no idea a player is involved.
	self._maid:GiveTask(self._slotsDataStore.SlotContainerParent:Mount(self._obj))

	self._remoting = self._maid:Add(Remoting.Server.new(self._obj, "HasSaveSlots"))

	self:_setupSummary()
	self:_setupRemotes()

	self._maid:GiveTask(HasSaveSlotsInterface.Server:Implement(self._obj, self))

	return self
end

--[=[
	Returns the underlying player-independent slot system, a [HasSaveSlotsDataStore]. Prefer the
	delegating methods on this class; this is for code that needs to hand the slot system to something
	that does not know about players.

	Typed `any` deliberately: naming `HasSaveSlotsDataStore.HasSaveSlotsDataStore` anywhere in this
	file -- even once -- pushes the old solver over its complexity budget ("Code is too complex"). The
	delegating methods below still carry their own precise return types, which is what callers read;
	require the module directly for a typed handle.

	@return HasSaveSlotsDataStore
]=]
function HasSaveSlots.GetSlotsDataStore(self: HasSaveSlots): any
	return self._slotsDataStore
end

--[=[
	Observes the [DataStoreStage] for the active slot as a [Brio]
]=]
function HasSaveSlots.ObserveActiveSlotStoreBrio(
	self: HasSaveSlots
): Observable.Observable<Brio.Brio<DataStoreStage.DataStoreStage>>
	return self._slotsDataStore:ObserveActiveSlotStoreBrio()
end

--[=[
	Returns the [DataStoreStage] for the active slot
]=]
function HasSaveSlots.PromiseActiveSlotStore(self: HasSaveSlots): Promise.Promise<DataStoreStage.DataStoreStage?>
	return self._slotsDataStore:PromiseActiveSlotStore()
end

--[=[
	Promises that all slots have loaded
]=]
function HasSaveSlots.PromiseSlotsLoaded(self: HasSaveSlots): Promise.Promise<any>
	return self._slotsDataStore:PromiseSlotsLoaded()
end

--[=[
	Returns whether the slot with the given ID exists
]=]
function HasSaveSlots.PromiseHasSlot(self: HasSaveSlots, slotId: SaveSlotData.SlotId?): Promise.Promise<boolean>
	return self._slotsDataStore:PromiseHasSlot(slotId)
end

-- SaveSlotService owns the callbacks and runs them. Reached through the module instance rather than by
-- name, because `require("SaveSlotService")` from here -- at any depth, even inside this function -- is a
-- cyclic module dependency: SaveSlotService requires this module. A binder bound without the service in
-- its bag has nothing to ask, and allows the selection.
function HasSaveSlots._promisePreSelectFromSaveSlotService(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId
): Promise.Promise<boolean>
	local serviceModule = script.Parent.Parent:FindFirstChild("SaveSlotService")
	if not serviceModule or not self._serviceBag:HasService(serviceModule) then
		return (Promise :: any).resolved(true)
	end

	return self._serviceBag:GetService(serviceModule):PromisePreSelect(self._obj, slotId, self.ActiveSlotId.Value)
end

--[=[
	Selects the slot with the given ID
]=]
function HasSaveSlots.PromiseSelectSlot(self: HasSaveSlots, slotId: SaveSlotData.SlotId): Promise.Promise<any>
	return self._slotsDataStore:PromiseSelectSlot(slotId)
end

--[=[
	Clears the active slot selection, returning the player to a no-slot state --
	the counterpart to [HasSaveSlots.PromiseSelectSlot], backing a "back to menu"
	affordance. See [HasSaveSlotsDataStore.PromiseDeselectSlot].
]=]
function HasSaveSlots.PromiseDeselectSlot(self: HasSaveSlots): Promise.Promise<()>
	return self._slotsDataStore:PromiseDeselectSlot()
end

--[=[
	Creates a slot at the given index
]=]
function HasSaveSlots.PromiseCreateSlot(
	self: HasSaveSlots,
	slotIndex: number,
	metadata: SaveSlotCreateMetadata?
): Promise.Promise<SaveSlotData.SlotId>
	return self._slotsDataStore:PromiseCreateSlot(slotIndex, metadata)
end

--[=[
	Exports a slot's saved data into a plain, serializable [SaveSlotExportUtils.SaveSlotExport]. Refuses
	the main slot unless `allowMainSlot` is set -- see [HasSaveSlotsDataStore.PromiseExportSlot].

	@param slotId SlotId
	@param allowMainSlot boolean? -- defaults to false
	@return Promise<SaveSlotExportUtils.SaveSlotExport>
]=]
function HasSaveSlots.PromiseExportSlot(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId,
	allowMainSlot: boolean?
): Promise.Promise<SaveSlotExportUtils.SaveSlotExport>
	return self._slotsDataStore:PromiseExportSlot(slotId, allowMainSlot)
end

--[=[
	Imports an exported slot into a fresh slot at the lowest free non-main index. See
	[HasSaveSlotsDataStore.PromiseImportSlot].

	@param export SaveSlotExportUtils.SaveSlotExport
	@return Promise<SlotId>
]=]
function HasSaveSlots.PromiseImportSlot(
	self: HasSaveSlots,
	export: SaveSlotExportUtils.SaveSlotExport
): Promise.Promise<SaveSlotData.SlotId>
	return self._slotsDataStore:PromiseImportSlot(export)
end

--[=[
	Exports a non-main slot and writes it to the shared save slot store under the given key. See
	[HasSaveSlotsDataStore.PromiseSaveSlotToSharedDataStore].

	@param slotId SlotId
	@param key string
	@param allowMainSlot boolean? -- defaults to false
	@return Promise<boolean>
]=]
function HasSaveSlots.PromiseSaveSlotToSharedDataStore(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId,
	key: string,
	allowMainSlot: boolean?
): Promise.Promise<boolean>
	return self._slotsDataStore:PromiseSaveSlotToSharedDataStore(slotId, key, allowMainSlot)
end

--[=[
	Reads an export from the shared save slot store and imports it into a fresh non-main slot. See
	[HasSaveSlotsDataStore.PromiseImportSlotFromSharedDataStore].

	@param key string
	@return Promise<SlotId>
]=]
function HasSaveSlots.PromiseImportSlotFromSharedDataStore(
	self: HasSaveSlots,
	key: string
): Promise.Promise<SaveSlotData.SlotId>
	return self._slotsDataStore:PromiseImportSlotFromSharedDataStore(key)
end

--[=[
	Loads the export stored under the given shared-store key into a fresh ephemeral slot and selects it.
	See [HasSaveSlotsDataStore.PromiseSelectTransferableEphemeralSlot].

	@param key string
	@return Promise<SlotId>
]=]
function HasSaveSlots.PromiseSelectTransferableEphemeralSlot(
	self: HasSaveSlots,
	key: string
): Promise.Promise<SaveSlotData.SlotId>
	return self._slotsDataStore:PromiseSelectTransferableEphemeralSlot(key)
end

--[=[
	Builds this player's teleport slice for a transferable ephemeral slot. See
	[HasSaveSlotsDataStore.PromiseBuildEphemeralTransferSlice].

	@return Promise<{ [string]: any }?>
]=]
function HasSaveSlots.PromiseBuildEphemeralTransferSlice(self: HasSaveSlots): Promise.Promise<{ [string]: any }?>
	return self._slotsDataStore:PromiseBuildEphemeralTransferSlice()
end

--[=[
	Selects the transferable ephemeral slot the player teleported in with, from the shared-store key in
	their arrived data. Reads the *unified* band (not trusted-only) so a **client-initiated** teleport --
	the common case, e.g. a menu resume hop -- carries it too; a server-initiated teleport still works via
	the trusted band. Resolves to the slot id, or nil when none arrived.

	Because the client band is honored, a client can present any key it knows. The key resolves to a
	server-side shared-store entry and only ever seeds a throwaway (never-persisted) slot, so the exposure
	is read-only visibility of a snapshot whose code you already have -- acceptable for the dev/Cmdr tooling
	this backs. Harden (longer code entropy / ownership) before exposing it to a player-facing surface.

	@return Promise<SlotId?>
]=]
function HasSaveSlots.PromiseLoadTransferableEphemeralSlotFromTeleport(
	self: HasSaveSlots
): Promise.Promise<SaveSlotData.SlotId?>
	return self._teleportDataService
		:PromiseArrivedValue(self._obj, SaveSlotConstants.TELEPORT_DATA_EPHEMERAL_KEY)
		:Then(function(key): any
			if type(key) ~= "string" then
				return nil
			end
			return self:PromiseSelectTransferableEphemeralSlot(key)
		end)
end

--[=[
	Overrides the share-code generator for this player's exports (see [SaveSlotCodeUtils.CodeGenerator]).
	Games inject a custom format; the default is [SaveSlotCodeUtils.generateDefaultCode]. Usually set
	game-wide via [SaveSlotService.SetCodeGenerator] rather than per player.

	@param generator CodeGenerator
]=]
function HasSaveSlots.SetCodeGenerator(self: HasSaveSlots, generator: SaveSlotCodeUtils.CodeGenerator): ()
	self._slotsDataStore:SetCodeGenerator(generator)
end

--[=[
	Exports a slot to the shared store under a fresh generated code and resolves to that code. See
	[HasSaveSlotsDataStore.PromiseExportSaveSlotToCode].

	@param slotId SlotId? -- defaults to the active slot
	@param allowMainSlot boolean? -- defaults to false
	@return Promise<string>
]=]
function HasSaveSlots.PromiseExportSaveSlotToCode(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId?,
	allowMainSlot: boolean?
): Promise.Promise<string>
	return self._slotsDataStore:PromiseExportSaveSlotToCode(slotId, allowMainSlot)
end

--[=[
	Loads the slot stored under the given code into a fresh transferable ephemeral slot and selects it.
	See [HasSaveSlotsDataStore.PromiseImportEphemeralSaveSlotFromCode].

	@param code string
	@return Promise<SlotId>
]=]
function HasSaveSlots.PromiseImportEphemeralSaveSlotFromCode(
	self: HasSaveSlots,
	code: string
): Promise.Promise<SaveSlotData.SlotId>
	return self._slotsDataStore:PromiseImportEphemeralSaveSlotFromCode(code)
end

--[=[
	Exports a slot as a raw JSON string (no shared store). See
	[HasSaveSlotsDataStore.PromiseExportSaveSlotToJson].

	@param slotId SlotId? -- defaults to the active slot
	@param allowMainSlot boolean? -- defaults to false
	@return Promise<string>
]=]
function HasSaveSlots.PromiseExportSaveSlotToJson(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId?,
	allowMainSlot: boolean?
): Promise.Promise<string>
	return self._slotsDataStore:PromiseExportSaveSlotToJson(slotId, allowMainSlot)
end

--[=[
	Duplicates the slot with the given ID into a new slot at the lowest free index, copying its saved
	data and accrued playtime. See [HasSaveSlotsDataStore.PromiseDuplicateSlot].
]=]
function HasSaveSlots.PromiseDuplicateSlot(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId
): Promise.Promise<SaveSlotData.SlotId>
	return self._slotsDataStore:PromiseDuplicateSlot(slotId)
end

--[=[
	Turns an ephemeral slot into a real save and selects it. See
	[HasSaveSlotsDataStore.PromisePersistEphemeralSlot].

	@param slotId SlotId? -- defaults to the active slot
	@return Promise<SlotId>
]=]
function HasSaveSlots.PromisePersistEphemeralSlot(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId?
): Promise.Promise<SaveSlotData.SlotId>
	return self._slotsDataStore:PromisePersistEphemeralSlot(slotId)
end

--[=[
	Deletes the slot with the given ID. See [HasSaveSlotsDataStore.PromiseDeleteSlot].
]=]
function HasSaveSlots.PromiseDeleteSlot(self: HasSaveSlots, slotId: SaveSlotData.SlotId): Promise.Promise<any>
	return self._slotsDataStore:PromiseDeleteSlot(slotId)
end

--[=[
	Deletes every slot for the player and clears the active/last-active
	selection, resetting the player to a fresh state. Resolves once all slots
	are gone.
]=]
function HasSaveSlots.PromiseDeleteAllSlots(self: HasSaveSlots): Promise.Promise<any>
	return self._slotsDataStore:PromiseDeleteAllSlots()
end

--[=[
	Resets the slot with the given id to a fresh empty one. See [HasSaveSlotsDataStore.PromiseResetSlot].
]=]
function HasSaveSlots.PromiseResetSlot(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId
): Promise.Promise<SaveSlotData.SlotId>
	return self._slotsDataStore:PromiseResetSlot(slotId)
end

--[=[
	Resets the active slot to a fresh empty one -- see [HasSaveSlots.PromiseResetSlot]. Resolves to the
	new slot id, or nil when no slot is active.
]=]
function HasSaveSlots.PromiseResetActiveSlot(self: HasSaveSlots): Promise.Promise<SaveSlotData.SlotId?>
	return self._slotsDataStore:PromiseResetActiveSlot()
end

--[=[
	Sets the metadata for the slot with the given ID
]=]
function HasSaveSlots.PromiseSetSlotMetadata(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId,
	data: SaveSlotData.SaveSlotMetadata
): Promise.Promise<any>
	return self._slotsDataStore:PromiseSetSlotMetadata(slotId, data)
end

--[=[
	Gets the metadata for the slot with the given ID
]=]
function HasSaveSlots.PromiseGetSlotMetadata(
	self: HasSaveSlots,
	slotId: SaveSlotData.SlotId
): Promise.Promise<SaveSlotData.SaveSlotMetadata?>
	return self._slotsDataStore:PromiseGetSlotMetadata(slotId)
end

--[=[
	Returns the slot ID from the given index
]=]
function HasSaveSlots.PromiseSlotIdFromIndex(
	self: HasSaveSlots,
	slotIndex: number
): Promise.Promise<SaveSlotData.SlotId?>
	return self._slotsDataStore:PromiseSlotIdFromIndex(slotIndex)
end

--[=[
	Gets the last active slot ID
]=]
function HasSaveSlots.PromiseLastActiveSlotId(self: HasSaveSlots): Promise.Promise<SaveSlotData.SlotId?>
	return self._slotsDataStore:PromiseLastActiveSlotId()
end

--[=[
	Selects the player's last active slot if one still exists, resolving to the
	selected slot id -- or nil when there is no slot to continue on. Backs a
	"Continue" affordance that every save-slot consumer tends to need.
]=]
function HasSaveSlots.PromiseSelectLastSaveSlot(self: HasSaveSlots): Promise.Promise<SaveSlotData.SlotId?>
	return self._slotsDataStore:PromiseSelectLastSaveSlot()
end

--[=[
	Creates a new slot at the lowest free index and selects it, resolving to the
	new slot id -- or nil when every slot is already in use. Backs a "New Game"
	affordance.
]=]
function HasSaveSlots.PromiseSelectNewSaveSlot(self: HasSaveSlots): Promise.Promise<SaveSlotData.SlotId?>
	return self._slotsDataStore:PromiseSelectNewSaveSlot()
end

--[=[
	Creates a fresh ephemeral slot and selects it, resolving to its id. See
	[HasSaveSlotsDataStore.PromiseSelectEphemeralSlot].

	@param metadata SaveSlotCreateMetadata? -- optional SlotName/Summary for the in-memory slot
	@return Promise<SlotId>
]=]
function HasSaveSlots.PromiseSelectEphemeralSlot(
	self: HasSaveSlots,
	metadata: SaveSlotCreateMetadata?
): Promise.Promise<SaveSlotData.SlotId>
	return self._slotsDataStore:PromiseSelectEphemeralSlot(metadata)
end

--[=[
	Registers a named summary provider. Every registered provider's current value is aggregated into
	the active slot's Summary, keyed by `name` (see [HasSaveSlots.PromiseGetSlotMetadata]). Registering
	the same name again replaces the previous provider. Returns a function that unregisters the provider
	(also give it to a [Maid]).

	@param name string
	@param provider SummaryProvider
	@return () -> ()
]=]
function HasSaveSlots.RegisterSummaryProvider(self: HasSaveSlots, name: string, provider: SummaryProvider): () -> ()
	assert(type(name) == "string", "Bad name")
	assert(type(provider) == "function", "Bad provider")

	return self._summaryProviders:Set(name, provider :: any)
end

-- Server realm hook for HasSaveSlotsBase: the incoming slot id is whatever the player teleported in
-- with, read from the unified TeleportDataService view. It is a promise because a client-initiated
-- teleport only reaches the server once the client replicates its arrived data. The slot id is a
-- client *request* -- fine here, because PromiseLoadSaveSlotFromTeleport re-validates ownership via
-- PromiseHasSlot before selecting it.
function HasSaveSlots.PromiseIncomingSlotId(self: HasSaveSlots): Promise.Promise<SaveSlotData.SlotId?>
	return self._teleportDataService
		:PromiseArrivedValue(self._obj, SaveSlotConstants.TELEPORT_DATA_SLOT_KEY)
		:Then(function(slotId): SaveSlotData.SlotId?
			if type(slotId) == "string" then
				return slotId
			end
			return nil
		end)
end

function HasSaveSlots._setupSummary(self: HasSaveSlots): ()
	self._maid:GiveTask(
		self:ObserveActiveSlotStoreBrio():Subscribe(function(brio: Brio.Brio<DataStoreStage.DataStoreStage>)
			if brio:IsDead() then
				return
			end

			local activeSlot = self._slotsDataStore:GetSlotFolder(self.ActiveSlotId.Value)
			if not activeSlot then
				return
			end

			local maid, slotStore = brio:ToMaidAndValue()

			maid:GiveTask(self:_observeSummary(slotStore):Subscribe(function(summary: SaveSlotData.SaveSlotSummary)
				-- An empty aggregate (no providers, or every one errored/contributed nothing) clears the
				-- Summary rather than persisting an empty table.
				SaveSlotData.Summary:Set(activeSlot, if next(summary) ~= nil then summary else nil)
			end))
		end)
	)
end

-- Aggregates every registered summary provider's current value into one table keyed by provider name,
-- re-aggregating whenever a provider is registered or unregistered. Always emits a table (possibly
-- empty); providers that contribute nothing are simply absent from it.
function HasSaveSlots._observeSummary(
	self: HasSaveSlots,
	slotStore: DataStoreStage.DataStoreStage
): Observable.Observable<SaveSlotData.SaveSlotSummary>
	return self._summaryProviders:ObserveKeyList():Pipe({
		Rx.switchMap(function(names: { string })
			if #names == 0 then
				return Rx.of({}) :: any
			end

			local observablesByName = {}
			for _, name in names do
				observablesByName[name] = self:_observeProviderValue(name, slotStore)
			end

			return Rx.combineLatest(observablesByName):Pipe({
				Rx.map(function(valuesByName: { [string]: any }): SaveSlotData.SaveSlotSummary
					local summary = {}
					for name, value in valuesByName do
						if value ~= NONE then
							summary[name] = value
						end
					end
					return summary
				end) :: any,
			}) :: any
		end) :: any,
	}) :: any
end

-- Observes the value contributed by the provider registered under `name`, isolating it: an error when
-- calling the provider, a non-Observable return, or a mid-stream error all resolve to the NONE sentinel
-- so one bad provider neither stalls nor fails the aggregate. Tracks provider replacement at `name`.
function HasSaveSlots._observeProviderValue(
	self: HasSaveSlots,
	name: string,
	slotStore: DataStoreStage.DataStoreStage
): Observable.Observable<any>
	return self._summaryProviders:ObserveAtKey(name):Pipe({
		Rx.switchMap(function(provider: SummaryProvider?)
			if not provider then
				return Rx.of(NONE) :: any
			end

			local success, observable = pcall(provider, self._obj, slotStore)
			if not success then
				warn(`[HasSaveSlots] Summary provider {name} errored: {observable}`)
				return Rx.of(NONE) :: any
			end

			if not Observable.isObservable(observable) then
				warn(`[HasSaveSlots] Summary provider {name} did not return an Observable`)
				return Rx.of(NONE) :: any
			end

			return (observable :: any):Pipe({
				Rx.catchError(function(err)
					warn(`[HasSaveSlots] Summary provider {name} stream errored: {err}`)
					return Rx.of(NONE)
				end) :: any,
			})
		end) :: any,
	}) :: any
end

function HasSaveSlots._setupRemotes(self: HasSaveSlots): ()
	self._maid:GiveTask(self._remoting.PromiseHasSlot:Bind(function(remotePlayer: Player, ...)
		if remotePlayer == self._obj then
			return self:PromiseHasSlot(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseSelectSlot:Bind(function(remotePlayer: Player, ...)
		if remotePlayer == self._obj then
			return self:PromiseSelectSlot(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseCreateSlot:Bind(function(remotePlayer: Player, ...)
		if remotePlayer == self._obj then
			return self:PromiseCreateSlot(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseDeleteSlot:Bind(function(remotePlayer: Player, ...)
		if remotePlayer == self._obj then
			return self:PromiseDeleteSlot(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseSetSlotMetadata:Bind(function(remotePlayer: Player, ...)
		if remotePlayer == self._obj then
			return self:PromiseSetSlotMetadata(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseGetSlotMetadata:Bind(function(remotePlayer: Player, ...)
		if remotePlayer == self._obj then
			return self:PromiseGetSlotMetadata(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseSlotIdFromIndex:Bind(function(remotePlayer: Player, ...)
		if remotePlayer == self._obj then
			return self:PromiseSlotIdFromIndex(...)
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))

	self._maid:GiveTask(self._remoting.PromiseLastActiveSlotId:Bind(function(remotePlayer: Player)
		if remotePlayer == self._obj then
			return self:PromiseLastActiveSlotId()
		else
			return (Promise :: any).rejected("Bad player")
		end
	end))
end

return PlayerBinder.new("HasSaveSlots", HasSaveSlots :: any) :: Binder.Binder<HasSaveSlots>
