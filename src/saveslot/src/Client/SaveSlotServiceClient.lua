--!strict
--[=[
	@class SaveSlotServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HasSaveSlotsData = require("HasSaveSlotsData")
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

function SaveSlotServiceClient.Start(self: SaveSlotServiceClient)
	-- Symmetric mirror of the server's provider ([SaveSlotService.Start]): a teleport the client builds
	-- carries the local player's active slot id, so a client-initiated teleport resumes on the same slot
	-- without any menu re-attaching it by hand.
	self._maid:GiveTask(
		self._teleportDataServiceClient:RegisterPerPlayerTeleportDataProvider(
			function(player: Player): { [string]: any }?
				-- A transferable ephemeral slot resumes at the destination from its shared-store key -- its
				-- own (ephemeral) slot id is not a resumable persisted slot there -- so carry the key when one
				-- is active. Otherwise carry the active real slot id, as before.
				local ephemeralKey = HasSaveSlotsData.ActiveTransferableEphemeralKey:Get(player)
				if type(ephemeralKey) == "string" then
					return { [SaveSlotConstants.TELEPORT_DATA_EPHEMERAL_KEY] = ephemeralKey }
				end
				local slotId = HasSaveSlotsData.ActiveSlotId:Get(player)
				if type(slotId) == "string" then
					return { [SaveSlotConstants.TELEPORT_DATA_SLOT_KEY] = slotId }
				end
				return nil
			end
		)
	)
end

--[=[
	Resolves whether the local player teleported in carrying a save-slot id -- i.e. arrived via an
	internal slot teleport rather than a fresh join. Presence-only. A promise for symmetry with the
	server's [SaveSlotService.PromiseIsInternalTeleport]; on the client it resolves immediately from
	local teleport data.

	@return Promise<boolean>
]=]
function SaveSlotServiceClient.PromiseIsInternalTeleport(self: SaveSlotServiceClient): any
	return self._teleportDataServiceClient:PromiseHasArrivedValue(SaveSlotConstants.TELEPORT_DATA_SLOT_KEY)
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
