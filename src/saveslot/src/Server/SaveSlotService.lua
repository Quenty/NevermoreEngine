--!strict
--[=[
	@class SaveSlotService
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brio = require("Brio")
local DataStoreStage = require("DataStoreStage")
local HasSaveSlots = require("HasSaveSlots")
local HasSaveSlotsData = require("HasSaveSlotsData")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableMap = require("ObservableMap")
local Promise = require("Promise")
local Remoting = require("Remoting")
local RxBrioUtils = require("RxBrioUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local SaveSlotExportUtils = require("SaveSlotExportUtils")
local ServiceBag = require("ServiceBag")
local SharedSaveSlotDataStoreService = require("SharedSaveSlotDataStoreService")
local TeleportDataService = require("TeleportDataService")

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
		_remoting: any,
		_teleportDataService: any,
	},
	{} :: typeof({ __index = SaveSlotService })
))

function SaveSlotService.Init(self: SaveSlotService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("PlayerDataStoreService"))
	self._teleportDataService = self._serviceBag:GetService(TeleportDataService)

	-- Registered here (pre-start) so the HasSaveSlots binder can acquire it when a player binds,
	-- which happens after Start. Mirrors how PlayerDataStoreService/TeleportDataService are pulled in.
	self._serviceBag:GetService(SharedSaveSlotDataStoreService)

	-- Internal
	self._serviceBag:GetService(require("SaveSlotCmdrService"))
	self._serviceBag:GetService(require("SaveSlotDataService"))

	-- Binders
	self._hasSaveSlotsBinder = self._serviceBag:GetService(HasSaveSlots)

	self._selectionRequired = false
	self._maxSlotCount = 1
	self._defaultSummaryProviders = self._maid:Add(ObservableMap.new())

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
	[HasSaveSlots.PromiseLoadEphemeralSaveSlotFromCode].
]=]
function SaveSlotService.PromiseLoadEphemeralSaveSlotFromCode(
	self: SaveSlotService,
	player: Player,
	code: string
): Promise.Promise<SaveSlotData.SlotId>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseLoadEphemeralSaveSlotFromCode(code)
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
