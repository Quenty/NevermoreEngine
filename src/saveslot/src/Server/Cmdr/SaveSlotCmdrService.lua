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
		local activeSlotId = self._saveSlotDataService:GetActiveSlotId(context.Executor)
		local slotList = self._saveSlotDataService:GetSlotList(context.Executor)
		local listString = ""

		for _, slot in slotList do
			local isActive = (slot.SlotId == activeSlotId)
			listString ..= `\n"{slot.SlotName}" ({slot.SlotIndex}){isActive and " — Active" or ""}\n{slot.Summary}\n`
		end

		return listString
	end)

	self._cmdrService:RegisterCommand({
		Name = "get-active-save-slot",
		Description = "Returns the active save slot.",
		Group = "SaveSlots",
		Args = {},
	}, function(context)
		local activeSlotId = self._saveSlotDataService:GetActiveSlotId(context.Executor)
		if not activeSlotId then
			return "No active slot."
		end

		local slotData = self._saveSlotDataService:GetSlotMetadata(context.Executor, activeSlotId)

		return `Currently using slot {slotData.SlotIndex} ("{slotData.SlotName}").`
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
		local slotId = self._saveSlotDataService:GetSlotIdFromIndex(context.Executor, slotIndex)
		if not slotId then
			return `No slot with index {slotIndex}.`
		end

		if slotId == self._saveSlotDataService:GetActiveSlotId(context.Executor) then
			return "Slot is already active."
		end

		self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseSelectSlot(slotId)
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

		local slotId = self._saveSlotDataService:GetSlotIdFromIndex(context.Executor, slotIndex)
		if slotId then
			return "Slot already exists."
		end

		self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseCreateSlot(slotIndex)
			end)
			:Wait()

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
		local slotId = self._saveSlotDataService:GetSlotIdFromIndex(context.Executor, slotIndex)
		if not slotId then
			return `No slot with index {slotIndex}.`
		end

		if slotId == self._saveSlotDataService:GetActiveSlotId(context.Executor) then
			return "Cannot delete active slot."
		end

		self._maid
			:GivePromise(self._hasSaveSlotsBinder:Promise(context.Executor))
			:Then(function(hasSaveSlots)
				return hasSaveSlots:PromiseDeleteSlot(slotId)
			end)
			:Wait()

		return `Deleted slot {slotIndex}.`
	end)
end

function SaveSlotCmdrService.Destroy(self: SaveSlotCmdrService): ()
	self._maid:Destroy()
end

return SaveSlotCmdrService
