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
local SaveSlotConstants = require("SaveSlotConstants")
local SaveSlotData = require("SaveSlotData")
local ServiceBag = require("ServiceBag")
local TeleportDataServiceClient = require("TeleportDataServiceClient")

local HasSaveSlotsClient = setmetatable({}, HasSaveSlotsBase)
HasSaveSlotsClient.ClassName = "HasSaveSlotsClient"
HasSaveSlotsClient.__index = HasSaveSlotsClient

export type HasSaveSlotsClient =
	typeof(setmetatable(
		{} :: {
			_obj: Player,
			_serviceBag: ServiceBag.ServiceBag,
			_remoting: any,
			_teleportDataServiceClient: any,
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
	self._teleportDataServiceClient = self._serviceBag:GetService(TeleportDataServiceClient)

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
): Promise.Promise<SaveSlotData.SaveSlotMetadata?>
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

-- Client realm hook for HasSaveSlotsBase: the incoming slot id is whatever the local player teleported
-- in with, read from the unified TeleportDataServiceClient view (a promise for symmetry with the
-- server; on the client it resolves immediately from local teleport data).
function HasSaveSlotsClient.PromiseIncomingSlotId(self: HasSaveSlotsClient): Promise.Promise<SaveSlotData.SlotId?>
	return self._teleportDataServiceClient
		:PromiseArrivedValue(SaveSlotConstants.TELEPORT_DATA_SLOT_KEY)
		:Then(function(slotId): SaveSlotData.SlotId?
			if type(slotId) == "string" then
				return slotId
			end
			return nil
		end)
end

return Binder.new("HasSaveSlots", HasSaveSlotsClient :: any) :: Binder.Binder<HasSaveSlotsClient>
