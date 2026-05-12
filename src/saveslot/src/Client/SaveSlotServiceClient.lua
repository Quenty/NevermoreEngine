--!strict
--[=[
	@class SaveSlotServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Maid = require("Maid")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")

local SaveSlotServiceClient = {}
SaveSlotServiceClient.ServiceName = "SaveSlotServiceClient"

export type SaveSlotServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_remoting: any,
	},
	{} :: typeof({ __index = SaveSlotServiceClient })
))

function SaveSlotServiceClient.Init(self: SaveSlotServiceClient, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- Internal
	self._serviceBag:GetService(require("SaveSlotCmdrServiceClient"))
	self._serviceBag:GetService(require("SaveSlotDataService"))

	-- Binders
	self._serviceBag:GetService(require("HasSaveSlotsClient"))

	self._remoting = self._maid:Add(Remoting.Client.new(ReplicatedStorage, "SaveSlotService"))
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
