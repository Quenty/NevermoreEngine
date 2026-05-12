--!strict
--[=[
	@class SaveSlotCmdrService
]=]

local require = require(script.Parent.loader).load(script)

local CmdrService = require("CmdrService")
local HasSaveSlots = require("HasSaveSlots")
local Maid = require("Maid")
local SaveSlotCmdrUtils = require("SaveSlotCmdrUtils")
local SaveSlotDataService = require("SaveSlotDataService")
local ServiceBag = require("ServiceBag")

local SaveSlotCmdrService = {}
SaveSlotCmdrService.ServiceName = "SaveSlotCmdrService"

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
		Args = {},
	}, function(context)
		local slotList = self._saveSlotDataService:GetSlotList(context.Executor)
		local listString = ""

		for _, slot in slotList do
			local isActive = (slot.SlotIndex == self._saveSlotDataService:GetActiveSlotIndex(context.Executor))
			listString ..= `\n"{slot.SlotName}" ({slot.SlotIndex}){isActive and " — Active" or ""}\n{slot.Summary}\n`
		end

		return listString
	end)

	self._cmdrService:RegisterCommand({
		Name = "active-save-slot",
		Description = "Returns the active save slot.",
		Group = "SaveSlots",
		Args = {},
	}, function(context)
		local slotIndex = self._saveSlotDataService:GetActiveSlotIndex(context.Executor)
		local slotData = self._saveSlotDataService:GetSlotMetadata(context.Executor, slotIndex)

		return `Currently using slot {slotIndex} ("{slotData.SlotName}").`
	end)

	self._cmdrService:RegisterCommand({
		Name = "set-save-slot",
		Description = "Switches to the given save slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Slot",
				Type = "slotIndex",
				Description = "Slot index to switch to.",
			},
		},
	}, function(context, slotIndex: number)
		self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseSelectSlot(slotIndex)
			end)
			:Wait()

		return `Switched to slot {slotIndex}.`
	end)

	self._cmdrService:RegisterCommand({
		Name = "create-save-slot",
		Description = "Creates a save slot at the given index.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Slot",
				Type = "number",
				Description = "Slot index to create.",
			},
		},
	}, function(context, slotIndex: number)
		local maxSlotCount = context.Executor:GetAttribute("MaxSlotCount")
		if (slotIndex < 1) or (slotIndex > maxSlotCount) then
			return `Index must be in range [1, {maxSlotCount}].`
		end

		local hasSaveSlots = self._maid:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor)):Wait()

		local hasSlot = self._maid:GivePromise(hasSaveSlots:PromiseHasSlot(slotIndex)):Wait()
		if hasSlot then
			return "Slot already exists."
		end

		self._maid:GivePromise(hasSaveSlots:PromiseCreateSlot(slotIndex)):Wait()

		return `Created slot {slotIndex}.`
	end)

	self._cmdrService:RegisterCommand({
		Name = "delete-save-slot",
		Description = "Deletes the given save slot.",
		Group = "SaveSlots",
		Args = {
			{
				Name = "Slot",
				Type = "slotIndex",
				Description = "Slot index to delete.",
			},
		},
	}, function(context, slotIndex: number)
		if slotIndex == self._saveSlotDataService:GetActiveSlotIndex(context.Executor) then
			return "Cannot delete active slot."
		end

		self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseDeleteSlot(slotIndex)
			end)
			:Wait()

		return `Deleted slot {slotIndex}.`
	end)
end

function SaveSlotCmdrService.Destroy(self: SaveSlotCmdrService): ()
	self._maid:Destroy()
end

return SaveSlotCmdrService
