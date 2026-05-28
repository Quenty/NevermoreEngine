--!strict
--[=[
	@class HasSaveSlotsClient
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local Binder = require("Binder")
local HasSaveSlotsBase = require("HasSaveSlotsBase")
local HasSaveSlotsInterface = require("HasSaveSlotsInterface")
local Promise = require("Promise")
local Remoting = require("Remoting")
local SaveSlotData = require("SaveSlotData")
local ServiceBag = require("ServiceBag")

local HasSaveSlotsClient = setmetatable({}, HasSaveSlotsBase)
HasSaveSlotsClient.ClassName = "HasSaveSlotsClient"
HasSaveSlotsClient.__index = HasSaveSlotsClient

export type HasSaveSlotsClient =
	typeof(setmetatable(
		{} :: {
			_obj: Player,
			_serviceBag: ServiceBag.ServiceBag,
			_remoting: any,
		},
		{} :: typeof({ __index = HasSaveSlotsClient })
	))
	& HasSaveSlotsBase.HasSaveSlotsBase

function HasSaveSlotsClient.new(player: Player, serviceBag: ServiceBag.ServiceBag): HasSaveSlotsClient
	if player ~= Players.LocalPlayer then
		return nil :: any
	end

	local self: HasSaveSlotsClient = setmetatable(HasSaveSlotsBase.new(player, serviceBag) :: any, HasSaveSlotsClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._remoting = self._maid:Add(Remoting.Client.new(self._obj, "HasSaveSlots"))

	self._maid:GiveTask(HasSaveSlotsInterface.Client:Implement(self._obj, self))

	return self
end

--[=[
	Returns whether the slot with the given ID exists
]=]
function HasSaveSlotsClient.PromiseHasSlot(
	self: HasSaveSlotsClient,
	slotId: SaveSlotData.SlotId?
): Promise.Promise<boolean>
	return self._remoting.PromiseHasSlot:PromiseInvokeServer(slotId)
end

--[=[
	Selects the slot with the given ID
]=]
function HasSaveSlotsClient.PromiseSelectSlot(
	self: HasSaveSlotsClient,
	slotId: SaveSlotData.SlotId
): Promise.Promise<any>
	return self._remoting.PromiseSelectSlot:PromiseInvokeServer(slotId)
end

--[=[
	Creates a slot at the given index
]=]
function HasSaveSlotsClient.PromiseCreateSlot(
	self: HasSaveSlotsClient,
	slotIndex: number,
	metadata: SaveSlotData.SaveSlotMetadata?
): Promise.Promise<any>
	return self._remoting.PromiseCreateSlot:PromiseInvokeServer(slotIndex, metadata)
end

--[=[
	Deletes the slot with the given ID
]=]
function HasSaveSlotsClient.PromiseDeleteSlot(
	self: HasSaveSlotsClient,
	slotId: SaveSlotData.SlotId
): Promise.Promise<any>
	return self._remoting.PromiseDeleteSlot:PromiseInvokeServer(slotId)
end

--[=[
	Sets the metadata for the slot with the given ID
]=]
function HasSaveSlotsClient.PromiseSetSlotMetadata(
	self: HasSaveSlotsClient,
	slotId: SaveSlotData.SlotId,
	data: SaveSlotData.SaveSlotMetadata
): Promise.Promise<any>
	return self._remoting.PromiseSetSlotMetadata:PromiseInvokeServer(slotId, data)
end

--[=[
	Gets the metadata for the slot with the given ID
]=]
function HasSaveSlotsClient.PromiseGetSlotMetadata(
	self: HasSaveSlotsClient,
	slotId: SaveSlotData.SlotId
): Promise.Promise<SaveSlotData.SaveSlotMetadata>
	return self._remoting.PromiseGetSlotMetadata:PromiseInvokeServer(slotId)
end

--[=[
	Gets the last active slot ID
]=]
function HasSaveSlotsClient.PromiseLastActiveSlotId(self: HasSaveSlotsClient): Promise.Promise<SaveSlotData.SlotId?>
	return self._remoting.PromiseLastActiveSlotId:PromiseInvokeServer()
end

--[=[
	Returns the slot ID from the given index
]=]
function HasSaveSlotsClient.PromiseSlotIdFromIndex(
	self: HasSaveSlotsClient,
	slotIndex: number
): Promise.Promise<SaveSlotData.SlotId?>
	return self._remoting.PromiseSlotIdFromIndex:PromiseInvokeServer(slotIndex)
end

return Binder.new("HasSaveSlots", HasSaveSlotsClient :: any) :: Binder.Binder<HasSaveSlotsClient>
