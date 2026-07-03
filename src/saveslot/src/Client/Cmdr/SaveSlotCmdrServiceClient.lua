--!strict
--[=[
	@class SaveSlotCmdrServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local CmdrServiceClient = require("CmdrServiceClient")
local Maid = require("Maid")
local SaveSlotCmdrUtils = require("SaveSlotCmdrUtils")
local SaveSlotDataService = require("SaveSlotDataService")
local ServiceBag = require("ServiceBag")

local SaveSlotCmdrServiceClient = {}
SaveSlotCmdrServiceClient.ServiceName = "SaveSlotCmdrServiceClient"

export type SaveSlotCmdrServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrServiceClient: any,
		_saveSlotDataService: any,
	},
	{} :: typeof({ __index = SaveSlotCmdrServiceClient })
))

function SaveSlotCmdrServiceClient.Init(self: SaveSlotCmdrServiceClient, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._cmdrServiceClient = self._serviceBag:GetService(CmdrServiceClient)

	-- Internal
	self._saveSlotDataService = self._serviceBag:GetService(SaveSlotDataService)
end

function SaveSlotCmdrServiceClient.Start(self: SaveSlotCmdrServiceClient)
	self._maid:GivePromise(self._cmdrServiceClient:PromiseCmdr()):Then(function(cmdr)
		SaveSlotCmdrUtils.registerSlotIndexType(cmdr, self._saveSlotDataService)
	end)
end

function SaveSlotCmdrServiceClient.Destroy(self: SaveSlotCmdrServiceClient): ()
	self._maid:Destroy()
end

return SaveSlotCmdrServiceClient
