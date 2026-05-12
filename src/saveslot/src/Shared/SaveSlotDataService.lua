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
	Observes the player's active slot index
]=]
function SaveSlotDataService.ObserveActiveSlotIndex(
	self: SaveSlotDataService,
	player: Player
): Observable.Observable<number?>
	return (HasSaveSlotsInterface:ObserveBrio(player, self._realm) :: any):Pipe({
		RxBrioUtils.switchMapBrio(function(hasSaveSlots)
			return hasSaveSlots.ActiveSlotIndex:Observe()
		end),
		RxBrioUtils.emitOnDeath(nil),
	})
end

--[=[
	Returns the player's active slot index
]=]
function SaveSlotDataService.GetActiveSlotIndex(self: SaveSlotDataService, player: Player): number?
	local hasSaveSlots = HasSaveSlotsInterface:Find(player, self._realm)
	return hasSaveSlots and hasSaveSlots.ActiveSlotIndex.Value
end

--[=[
	Observes the player's active slot list
]=]
function SaveSlotDataService.ObserveSlotList(
	_self: SaveSlotDataService,
	player: Player
): Observable.Observable<{ SaveSlotData.SaveSlotMetadata }?>
	return (
		RxInstanceUtils.observeLastNamedChildBrio(player, "Folder", SaveSlotConstants.METADATA_CONTAINER_NAME) :: any
	):Pipe({
		RxBrioUtils.switchMapBrio(function(slotContainer: Folder)
			return RxInstanceUtils.observeChildrenBrio(slotContainer):Pipe({
				RxBrioUtils.flatMapBrio(function(slotFolder)
					return SaveSlotData:Observe(slotFolder)
				end) :: any,
				RxBrioUtils.reduceToAliveList() :: any,
			})
		end),
		RxBrioUtils.emitOnDeath(nil),
	})
end

--[=[
	Returns the player's slot list
]=]
function SaveSlotDataService.GetSlotList(_self: SaveSlotDataService, player: Player): { SaveSlotData.SaveSlotMetadata }
	local slotList = {}

	local slotContainer = player:FindFirstChild(SaveSlotConstants.METADATA_CONTAINER_NAME)
	if slotContainer then
		for _, slot in slotContainer:GetChildren() do
			table.insert(slotList, SaveSlotData:Get(slot))
		end
	end

	return slotList
end

--[=[
	Observes the slot metadata at the given index for the player
]=]
function SaveSlotDataService.ObserveSlotMetadata(
	_self: SaveSlotDataService,
	player: Player,
	slotIndex: number
): Observable.Observable<SaveSlotData.SaveSlotMetadata?>
	return (
		RxInstanceUtils.observeLastNamedChildBrio(player, "Folder", SaveSlotConstants.METADATA_CONTAINER_NAME) :: any
	):Pipe({
		RxBrioUtils.switchMapBrio(function(slotContainer: Folder)
			return RxInstanceUtils.observeLastNamedChildBrio(slotContainer, "Folder", tostring(slotIndex))
		end),
		RxBrioUtils.emitOnDeath(nil),
		Rx.switchMap(function(slot: Folder?)
			return slot and SaveSlotData:Observe(slot) or Rx.EMPTY
		end),
	})
end

--[=[
	Returns the slot metadata at the given index for the player
]=]
function SaveSlotDataService.GetSlotMetadata(
	_self: SaveSlotDataService,
	player: Player,
	slotIndex: number
): SaveSlotData.SaveSlotMetadata?
	local slotContainer = player:FindFirstChild(SaveSlotConstants.METADATA_CONTAINER_NAME)
	local slot = slotContainer and slotContainer:FindFirstChild(tostring(slotIndex))

	if slot then
		return SaveSlotData:Get(slot)
	else
		return nil
	end
end

return SaveSlotDataService
