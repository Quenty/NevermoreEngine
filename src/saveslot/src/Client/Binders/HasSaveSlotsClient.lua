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
	Returns whether the slot at the given index exists
]=]
function HasSaveSlotsClient.PromiseHasSlot(self: HasSaveSlotsClient, slotIndex: number): Promise.Promise<boolean>
	return self._remoting.PromiseHasSlot:PromiseInvokeServer(slotIndex)
end

--[=[
	Selects the slot at the given index
]=]
function HasSaveSlotsClient.PromiseSelectSlot(self: HasSaveSlotsClient, slotIndex: number): Promise.Promise<any>
	return self._remoting.PromiseSelectSlot:PromiseInvokeServer(slotIndex)
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
	Deletes the slot at the given index
]=]
function HasSaveSlotsClient.PromiseDeleteSlot(self: HasSaveSlotsClient, slotIndex: number): Promise.Promise<any>
	return self._remoting.PromiseDeleteSlot:PromiseInvokeServer(slotIndex)
end

--[=[
	Sets the metadata for the slot at the given index
]=]
function HasSaveSlotsClient.PromiseSetSlotMetadata(
	self: HasSaveSlotsClient,
	slotIndex: number,
	data: SaveSlotData.SaveSlotMetadata
): Promise.Promise<any>
	return self._remoting.PromiseSetSlotMetadata:PromiseInvokeServer(slotIndex, data)
end

--[=[
	Gets the metadata for the slot at the given index
]=]
function HasSaveSlotsClient.PromiseGetSlotMetadata(
	self: HasSaveSlotsClient,
	slotIndex: number
): Promise.Promise<SaveSlotData.SaveSlotMetadata>
	return self._remoting.PromiseGetSlotMetadata:PromiseInvokeServer(slotIndex)
end

--[=[
	Gets the last active slot index
]=]
function HasSaveSlotsClient.PromiseLastActiveSlotIndex(self: HasSaveSlotsClient): Promise.Promise<number?>
	return self._remoting.PromiseLastActiveSlotIndex:PromiseInvokeServer()
end

--[=[
	Refreshes the active slot summary
]=]
function HasSaveSlotsClient.PromiseRefreshActiveSlotSummary(self: HasSaveSlotsClient): Promise.Promise<any>
	return self._remoting.PromiseRefreshActiveSlotSummary:PromiseInvokeServer()
end

return Binder.new("HasSaveSlots", HasSaveSlotsClient :: any) :: Binder.Binder<HasSaveSlotsClient>
