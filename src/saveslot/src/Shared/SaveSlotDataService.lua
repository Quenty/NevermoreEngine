--!strict
--[=[
	@class SaveSlotDataService
]=]

local require = require(script.Parent.loader).load(script)

local HasSaveSlotsInterface = require("HasSaveSlotsInterface")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local ServiceBag = require("ServiceBag")
local TieRealmService = require("TieRealmService")
local TieRealms = require("TieRealms")

local SaveSlotDataService = {}
SaveSlotDataService.ServiceName = "SaveSlotDataService"

export type SaveSlotDataService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_tieRealmService: TieRealmService.TieRealmService,
		_realm: TieRealms.TieRealm,
	},
	{} :: typeof({ __index = SaveSlotDataService })
))

function SaveSlotDataService.Init(self: SaveSlotDataService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._tieRealmService = self._serviceBag:GetService(TieRealmService) :: any

	self._realm = self._tieRealmService:GetTieRealm()
end

--[=[
	Observes the player's active slot ID. Emits nil -- rather than staying silent -- while the
	implementation has not replicated yet, so a subscriber always has a current answer.
]=]
function SaveSlotDataService.ObserveActiveSlotId(
	self: SaveSlotDataService,
	player: Player
): Observable.Observable<SaveSlotData.SlotId?>
	return (HasSaveSlotsInterface:ObserveBrio(player, self._realm) :: any):Pipe({
		RxBrioUtils.switchMapBrio(function(hasSaveSlots)
			return hasSaveSlots.ActiveSlotId:Observe()
		end),
		RxBrioUtils.emitOnDeath(nil),
		Rx.defaultsToNil :: any,
	})
end

--[=[
	Observes the player's last active slot ID (the slot they can continue on). Emits nil -- rather than
	staying silent -- while the implementation has not replicated yet.
]=]
function SaveSlotDataService.ObserveLastActiveSlotId(
	self: SaveSlotDataService,
	player: Player
): Observable.Observable<SaveSlotData.SlotId?>
	return (HasSaveSlotsInterface:ObserveBrio(player, self._realm) :: any):Pipe({
		RxBrioUtils.switchMapBrio(function(hasSaveSlots)
			return hasSaveSlots.LastActiveSlotId:Observe()
		end),
		RxBrioUtils.emitOnDeath(nil),
		Rx.defaultsToNil :: any,
	})
end

--[=[
	Returns the player's active slot ID
]=]
function SaveSlotDataService.GetActiveSlotId(self: SaveSlotDataService, player: Player): SaveSlotData.SlotId?
	local hasSaveSlots = HasSaveSlotsInterface:Find(player, self._realm)
	return hasSaveSlots and hasSaveSlots.ActiveSlotId.Value
end

--[=[
	Returns the player's last active slot ID -- the active slot when one is selected, otherwise the
	slot they last played and can continue on. This is the slot the "." shorthand resolves to in the
	save-slot Cmdr commands. The synchronous counterpart to
	[SaveSlotDataService.ObserveLastActiveSlotId].
]=]
function SaveSlotDataService.GetLastActiveSlotId(self: SaveSlotDataService, player: Player): SaveSlotData.SlotId?
	local hasSaveSlots = HasSaveSlotsInterface:Find(player, self._realm)
	if not hasSaveSlots then
		return nil
	end
	return hasSaveSlots.ActiveSlotId.Value or hasSaveSlots.LastActiveSlotId.Value
end

-- Ephemeral slots share the replicated container with real ones (so the client can resolve the active
-- slot's metadata), but they are throwaway sessions rather than saves -- every list read drops them.
-- This runs on the current metadata of each slot, so a slot whose IsEphemeral attribute lands after its
-- folder leaves the list as soon as the flag arrives, rather than sticking around as a phantom save.
local function withoutEphemeral(slotList: { SaveSlotData.SaveSlotMetadata }): { SaveSlotData.SaveSlotMetadata }
	local filtered = {}
	for _, metadata in slotList do
		if not metadata.IsEphemeral then
			table.insert(filtered, metadata)
		end
	end
	return filtered
end

--[=[
	Observes the player's active slot list. Ephemeral slots (see
	[HasSaveSlots.PromiseSelectEphemeralSlot]) are excluded -- observe the active slot's metadata
	directly with [SaveSlotDataService.ObserveSlotMetadata] to see one.

	Emits nil while the slot container has not replicated, then one entry per slot, re-emitting whenever
	a slot is added or removed or any slot's own metadata changes.
]=]
function SaveSlotDataService.ObserveSlotList(
	_self: SaveSlotDataService,
	player: Player
): Observable.Observable<{ SaveSlotData.SaveSlotMetadata }?>
	return (
		RxInstanceUtils.observeLastNamedChildBrio(player, "Folder", SaveSlotConstants.METADATA_CONTAINER_NAME) :: any
	):Pipe({
		-- Reduce to the live *folders* first and combineLatest their metadata, rather than flat-mapping
		-- each folder straight to metadata: a flat map adds an entry per emission, so every attribute
		-- change would append a second, stale entry for the same slot instead of replacing it.
		RxBrioUtils.switchMapBrio(function(slotContainer: Folder)
			return RxInstanceUtils.observeChildrenBrio(slotContainer):Pipe({
				RxBrioUtils.reduceToAliveList() :: any,
			})
		end),
		RxBrioUtils.emitOnDeath(nil),
		Rx.switchMap(function(slotFolders: { Instance }?)
			if not slotFolders then
				return Rx.of(nil) :: any
			end
			if #slotFolders == 0 then
				return Rx.of({}) :: any
			end

			local observables = {}
			for index, slotFolder in slotFolders do
				observables[index] = SaveSlotData:Observe(slotFolder)
			end

			return Rx.combineLatest(observables):Pipe({
				Rx.map(function(metadataByIndex: { any }): { SaveSlotData.SaveSlotMetadata }
					local slotList = {}
					for index = 1, #slotFolders do
						local metadata = metadataByIndex[index]
						if metadata ~= nil then
							table.insert(slotList, metadata)
						end
					end
					return withoutEphemeral(slotList)
				end) :: any,
			}) :: any
		end) :: any,
		Rx.defaultsToNil :: any,
	})
end

--[=[
	Returns the player's slot list. Ephemeral slots (see
	[HasSaveSlots.PromiseSelectEphemeralSlot]) are excluded -- read the active slot's metadata directly
	with [SaveSlotDataService.GetSlotMetadata] to see one.
]=]
function SaveSlotDataService.GetSlotList(_self: SaveSlotDataService, player: Player): { SaveSlotData.SaveSlotMetadata }
	local slotList = {}

	local slotContainer = player:FindFirstChild(SaveSlotConstants.METADATA_CONTAINER_NAME)
	if slotContainer then
		for _, slot in slotContainer:GetChildren() do
			table.insert(slotList, SaveSlotData:Get(slot))
		end
	end

	return withoutEphemeral(slotList)
end

--[=[
	Observes the slot metadata with the given ID for the player. Order-independent: the slot container,
	the slot folder, and the slot's own attributes each replicate on their own schedule, so this emits
	nil until the slot is actually there, the metadata once it is, again on every attribute that lands
	afterwards, and nil again the moment the slot goes away (which is how an ephemeral slot ends).
]=]
function SaveSlotDataService.ObserveSlotMetadata(
	_self: SaveSlotDataService,
	player: Player,
	slotId: SaveSlotData.SlotId
): Observable.Observable<SaveSlotData.SaveSlotMetadata?>
	return (
		RxInstanceUtils.observeLastNamedChildBrio(player, "Folder", SaveSlotConstants.METADATA_CONTAINER_NAME) :: any
	):Pipe({
		RxBrioUtils.switchMapBrio(function(slotContainer: Folder)
			return RxInstanceUtils.observeLastNamedChildBrio(slotContainer, "Folder", slotId)
		end),
		RxBrioUtils.emitOnDeath(nil),
		Rx.switchMap(function(slot: Folder?)
			-- Rx.of(nil), not Rx.EMPTY: an empty observable would swallow the slot's removal and leave
			-- the subscriber holding metadata for a slot that no longer exists.
			if not slot then
				return Rx.of(nil) :: any
			end
			return SaveSlotData:Observe(slot) :: any
		end),
		Rx.defaultsToNil :: any,
	})
end

--[=[
	Returns the slot metadata with the given ID for the player
]=]
function SaveSlotDataService.GetSlotMetadata(
	_self: SaveSlotDataService,
	player: Player,
	slotId: SaveSlotData.SlotId
): SaveSlotData.SaveSlotMetadata?
	local slotContainer = player:FindFirstChild(SaveSlotConstants.METADATA_CONTAINER_NAME)
	local slot = slotContainer and slotContainer:FindFirstChild(slotId)

	if slot then
		return SaveSlotData:Get(slot)
	else
		return nil
	end
end

--[=[
	Observes the metadata of whichever slot is currently active, following the selection as it changes
	and emitting nil while no slot is active. This is the read a UI showing "what am I playing right
	now" wants: composing [SaveSlotDataService.ObserveActiveSlotId] with
	[SaveSlotDataService.ObserveSlotMetadata] by hand is easy to get wrong, because the active-slot id
	and the slot folder it names replicate independently -- the id routinely arrives first.

	An ephemeral slot is included here (it is genuinely the active slot); it is only the *list* reads
	that exclude it.
]=]
function SaveSlotDataService.ObserveActiveSlotMetadata(
	self: SaveSlotDataService,
	player: Player
): Observable.Observable<SaveSlotData.SaveSlotMetadata?>
	return self:ObserveActiveSlotId(player):Pipe({
		Rx.switchMap(function(slotId: SaveSlotData.SlotId?)
			if not slotId then
				return Rx.of(nil) :: any
			end
			return self:ObserveSlotMetadata(player, slotId) :: any
		end) :: any,
		Rx.defaultsToNil :: any,
	}) :: any
end

--[=[
	Returns the metadata of whichever slot is currently active, or nil when no slot is active or its
	metadata has not replicated yet. The synchronous counterpart to
	[SaveSlotDataService.ObserveActiveSlotMetadata].
]=]
function SaveSlotDataService.GetActiveSlotMetadata(
	self: SaveSlotDataService,
	player: Player
): SaveSlotData.SaveSlotMetadata?
	local slotId = self:GetActiveSlotId(player)
	if not slotId then
		return nil
	end
	return self:GetSlotMetadata(player, slotId)
end

--[=[
	Observes whether the active slot is an ephemeral, never-persisted one (see
	[HasSaveSlots.PromiseSelectEphemeralSlot]) -- what a UI checks before offering "save", "delete", or
	anything else that only makes sense on a real save.

	Emits false while the answer is not known yet (no slot active, or the slot's metadata still in
	flight) and flips to true once the slot's IsEphemeral attribute lands, so a late attribute
	downgrades the UI rather than the reverse. Deduplicated, so it only emits on genuine changes.
]=]
function SaveSlotDataService.ObserveIsActiveSlotEphemeral(
	self: SaveSlotDataService,
	player: Player
): Observable.Observable<boolean>
	return self:ObserveActiveSlotMetadata(player):Pipe({
		Rx.map(function(metadata: SaveSlotData.SaveSlotMetadata?): boolean
			return metadata ~= nil and metadata.IsEphemeral == true
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

--[=[
	Returns whether the active slot is an ephemeral, never-persisted one. False when no slot is active
	or its metadata has not replicated yet. The synchronous counterpart to
	[SaveSlotDataService.ObserveIsActiveSlotEphemeral].
]=]
function SaveSlotDataService.IsActiveSlotEphemeral(self: SaveSlotDataService, player: Player): boolean
	local metadata = self:GetActiveSlotMetadata(player)
	return metadata ~= nil and metadata.IsEphemeral == true
end

--[=[
	Returns the ID for the slot at the given index
]=]
function SaveSlotDataService.GetSlotIdFromIndex(
	self: SaveSlotDataService,
	player: Player,
	slotIndex: number
): SaveSlotData.SlotId?
	for _, slot in self:GetSlotList(player) do
		if slotIndex == slot.SlotIndex then
			return slot.SlotId
		end
	end
	return nil
end

return SaveSlotDataService
