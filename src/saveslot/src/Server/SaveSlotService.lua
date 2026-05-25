--!strict
--[=[
	@class SaveSlotService
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brio = require("Brio")
local DataStoreStage = require("DataStoreStage")
local HasSaveSlots = require("HasSaveSlots")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Remoting = require("Remoting")
local RxBrioUtils = require("RxBrioUtils")
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local ServiceBag = require("ServiceBag")

local SaveSlotService = {}
SaveSlotService.ServiceName = "SaveSlotService"

export type SaveSlotService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_hasSaveSlotsBinder: any,
		_selectionRequired: boolean,
		_maxSlotCount: number,
		_summaryProvider: ((Player, any) -> string)?,
		_remoting: any,
	},
	{} :: typeof({ __index = SaveSlotService })
))

function SaveSlotService.Init(self: SaveSlotService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("PlayerDataStoreService"))

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
	self._maid:GiveTask(self._hasSaveSlotsBinder:ObserveAllBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, hasSaveSlots = brio:ToMaidAndValue()

		-- Pass consumer-specified configs
		hasSaveSlots.MaxSlotCount.Value = self._maxSlotCount
		if self._summaryProvider then
			hasSaveSlots:SetSummaryProvider(self._summaryProvider)
		end

		maid:GivePromise(hasSaveSlots:PromiseSlotsLoaded()):Then(function()
			if self._selectionRequired then
				return -- Consumer handles selection
			end

			-- Select last active slot
			return hasSaveSlots:PromiseLastActiveSlotId():Then(function(lastActiveSlotId: string?)
				return hasSaveSlots:PromiseHasSlot(lastActiveSlotId):Then(function(hasLastSlot: boolean)
					if hasLastSlot then
						return hasSaveSlots:PromiseSelectSlot(lastActiveSlotId)
					end

					-- Or create and select default slot
					return hasSaveSlots
						:PromiseSlotIdFromIndex(SaveSlotConstants.DEFAULT_SLOT_INDEX)
						:Then(function(defaultSlotId: string?)
							if defaultSlotId then
								return defaultSlotId
							else
								return hasSaveSlots:PromiseCreateSlot(SaveSlotConstants.DEFAULT_SLOT_INDEX)
							end
						end)
						:Then(function(slotId: string)
							return hasSaveSlots:PromiseSelectSlot(slotId)
						end)
				end)
			end)
		end)
	end))
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
	Sets the max slot count
]=]
function SaveSlotService.SetMaxSlotCount(self: SaveSlotService, maxSlotCount: number): ()
	assert(not self._serviceBag:IsStarted(), "SetMaxSlotCount must be called before Start")
	assert(maxSlotCount >= 1, "Bad maxSlotCount")
	self._maxSlotCount = maxSlotCount
end

--[=[
	Sets the slot summary provider
]=]
function SaveSlotService.SetSummaryProvider(self: SaveSlotService, provider: (Player, any) -> string): ()
	assert(type(provider) == "function", "Bad provider")
	self._summaryProvider = provider
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
function SaveSlotService.PromiseHasSlot(self: SaveSlotService, player: Player, slotId: string): Promise.Promise<boolean>
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
	slotId: string
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
function SaveSlotService.PromiseDeleteSlot(self: SaveSlotService, player: Player, slotId: string): Promise.Promise<any>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseDeleteSlot(slotId)
	end)
end

--[=[
	Refreshes the player's active slot summary
]=]
function SaveSlotService.PromiseRefreshActiveSlotSummary(self: SaveSlotService, player: Player): Promise.Promise<any>
	return self._hasSaveSlotsBinder:Promise(player):Then(function(hasSaveSlots)
		return hasSaveSlots:PromiseRefreshActiveSlotSummary()
	end)
end

--[=[
	Destroys the service
]=]
function SaveSlotService.Destroy(self: SaveSlotService): ()
	self._maid:Destroy()
end

return SaveSlotService
