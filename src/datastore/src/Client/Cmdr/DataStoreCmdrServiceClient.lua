--!strict
--[=[
	Client half of the datastore Cmdr commands. Cmdr parses arguments on the executor, so the types
	[DataStoreCmdrService]'s commands take have to be registered here too.

	@client
	@class DataStoreCmdrServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local CmdrServiceClient = require("CmdrServiceClient")
local DataStoreCmdrUtils = require("DataStoreCmdrUtils")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local DataStoreCmdrServiceClient = {}
DataStoreCmdrServiceClient.ServiceName = "DataStoreCmdrServiceClient"

export type DataStoreCmdrServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_cmdrServiceClient: any,
	},
	{} :: typeof({ __index = DataStoreCmdrServiceClient })
))

function DataStoreCmdrServiceClient.Init(self: DataStoreCmdrServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._cmdrServiceClient = self._serviceBag:GetService(CmdrServiceClient)
end

function DataStoreCmdrServiceClient.Start(self: DataStoreCmdrServiceClient): ()
	self._maid:GivePromise(self._cmdrServiceClient:PromiseCmdr()):Then(function(cmdr)
		DataStoreCmdrUtils.registerSubStoreType(cmdr)
	end)
end

function DataStoreCmdrServiceClient.Destroy(self: DataStoreCmdrServiceClient): ()
	self._maid:DoCleaning()
end

return DataStoreCmdrServiceClient
