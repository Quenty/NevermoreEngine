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
local Promise = require("Promise")
local Remoting = require("Remoting")
local RxBrioUtils = require("RxBrioUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local ServiceBag = require("ServiceBag")
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
		_defaultSummaryProvider: HasSaveSlots.SaveSlotSummaryProvider?,
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

	-- Internal
	self._serviceBag:GetService(require("SaveSlotCmdrService"))
	self._serviceBag:GetService(require("SaveSlotDataService"))

	-- Binders
	self._hasSaveSlotsBinder = self._serviceBag:GetService(HasSaveSlots)

	self._selectionRequired = false
	self._maxSlotCount = 1

	self._remoting = self._maid:Add(Remoting.Server.new(ReplicatedStorage, "SaveSlotService"))

	self._maid:GiveTask(self._remoting.GetExplicitSelectionRequired:Bind(function()
		return self:GetExplicitSelectionRequired()
	end))
end

function SaveSlotService.Start(self: SaveSlotService)
	-- Every teleport built through TeleportDataService for a single player carries that player's
	-- active slot id, so cross-place teleports resume on the same slot without each teleport site
	-- re-attaching it by hand.
	self._maid:GiveTask(
		self._teleportDataService:RegisterTeleportDataProvider(function(players: { Player }): { [string]: any }?
			if #players ~= 1 then
				return nil
			end

			local slotId = HasSaveSlotsData.ActiveSlotId:Get(players[1])
			if type(slotId) == "string" then
				return { [SaveSlotConstants.TELEPORT_DATA_SLOT_KEY] = slotId }
			end
			return nil
		end)
	)

	self._maid:GiveTask(self._hasSaveSlotsBinder:ObserveAllBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, hasSaveSlots = brio:ToMaidAndValue()

		-- Pass consumer-specified configs
		hasSaveSlots.MaxSlotCount.Value = self._maxSlotCount
		if self._defaultSummaryProvider then
			hasSaveSlots:SetSummaryProvider(self._defaultSummaryProvider)
		end

		-- Select the slot the player teleported in with, or proceed with the default flow
		maid:GivePromise(hasSaveSlots:PromiseSlotsLoaded()):Then(function()
			return hasSaveSlots:PromiseLoadSaveSlotFromTeleport():Then(function(loadedSlotId)
				if loadedSlotId then
					return -- Teleported in with a valid slot; it is now selected
				end
				return self:_promiseSelectDefaultSlot(hasSaveSlots)
			end)
		end)
	end))
end

--[=[
	Selects the player's last active slot, or creates and selects the default slot.
	Does nothing when explicit selection is required.
]=]
function SaveSlotService._promiseSelectDefaultSlot(self: SaveSlotService, hasSaveSlots: any): Promise.Promise<any>?
	if self._selectionRequired then
		return nil -- Consumer handles selection
	end

	return hasSaveSlots:PromiseLastActiveSlotId():Then(function(lastActiveSlotId: SaveSlotData.SlotId?)
		return hasSaveSlots:PromiseHasSlot(lastActiveSlotId):Then(function(hasLastSlot: boolean)
			if hasLastSlot then
				return hasSaveSlots:PromiseSelectSlot(lastActiveSlotId)
			end

			-- Or create and select default slot
			return hasSaveSlots
				:PromiseSlotIdFromIndex(SaveSlotConstants.DEFAULT_SLOT_INDEX)
				:Then(function(defaultSlotId: SaveSlotData.SlotId?)
					if defaultSlotId then
						return defaultSlotId
					else
						return hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX)
					end
				end)
				:Then(function(slotId: SaveSlotData.SlotId)
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
	Returns whether the player teleported in carrying a save-slot id -- i.e. arrived via an internal
	slot teleport rather than a fresh join. This is the sync, presence-only signal (it does not
	validate the slot still exists); use [HasSaveSlots.PromiseHasSaveSlotFromTeleport] when existence
	matters.

	@param player Player
	@return boolean
]=]
function SaveSlotService.IsInternalTeleport(self: SaveSlotService, player: Player): boolean
	return self._teleportDataService:HasArrivedValue(player, SaveSlotConstants.TELEPORT_DATA_SLOT_KEY)
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
	Sets the default slot summary provider
]=]
function SaveSlotService.SetDefaultSummaryProvider(
	self: SaveSlotService,
	provider: HasSaveSlots.SaveSlotSummaryProvider
): ()
	assert(type(provider) == "function", "Bad provider")
	self._defaultSummaryProvider = provider
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
	Destroys the service
]=]
function SaveSlotService.Destroy(self: SaveSlotService): ()
	self._maid:Destroy()
end

return SaveSlotService
