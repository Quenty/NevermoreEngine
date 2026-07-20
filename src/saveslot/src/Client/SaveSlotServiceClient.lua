--!strict
--[=[
	@class SaveSlotServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")
local Remoting = require("Remoting")
local SaveSlotConstants = require("SaveSlotConstants")
local ServiceBag = require("ServiceBag")
local TeleportDataServiceClient = require("TeleportDataServiceClient")

local SaveSlotServiceClient = {}
SaveSlotServiceClient.ServiceName = "SaveSlotServiceClient"

export type SaveSlotServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_remoting: any,
		_teleportDataServiceClient: any,
	},
	{} :: typeof({ __index = SaveSlotServiceClient })
))

function SaveSlotServiceClient.Init(self: SaveSlotServiceClient, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._teleportDataServiceClient = self._serviceBag:GetService(TeleportDataServiceClient)

	-- Internal
	self._serviceBag:GetService(require("SaveSlotCmdrServiceClient"))
	self._serviceBag:GetService(require("SaveSlotDataService"))

	-- Binders
	self._serviceBag:GetService(require("HasSaveSlotsClient"))

	self._remoting = self._maid:Add(Remoting.Client.new(ReplicatedStorage, "SaveSlotService"))
end

--[=[
	Returns whether the local player teleported in carrying a save-slot id -- i.e. arrived via an
	internal slot teleport rather than a fresh join. Sync, presence-only (mirrors the server's
	[SaveSlotService.IsInternalTeleport]).

	@return boolean
]=]
function SaveSlotServiceClient.IsInternalTeleport(self: SaveSlotServiceClient): boolean
	return self._teleportDataServiceClient:HasArrivedValue(SaveSlotConstants.TELEPORT_DATA_SLOT_KEY)
end

--[=[
	Returns whether explicit slot selection is required
]=]
function SaveSlotServiceClient.GetExplicitSelectionRequiredAsync(self: SaveSlotServiceClient): boolean
	return self._remoting.GetExplicitSelectionRequired:InvokeServer()
end

--[=[
	Destroys the service
]=]
function SaveSlotServiceClient.Destroy(self: SaveSlotServiceClient): ()
	self._maid:Destroy()
end

return SaveSlotServiceClient
