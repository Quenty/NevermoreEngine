--!strict
--[=[
	Entry point for the client half of the datastore package. Registers every client-side datastore
	service, so a consumer gets the package in one [ServiceBag.GetService].

	@client
	@class DataStoreServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local DataStoreServiceClient = {}
DataStoreServiceClient.ServiceName = "DataStoreServiceClient"

export type DataStoreServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = DataStoreServiceClient })
))

function DataStoreServiceClient.Init(self: DataStoreServiceClient, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("CmdrServiceClient"))

	-- Internal
	self._serviceBag:GetService(require("DataStoreCmdrServiceClient"))
end

return DataStoreServiceClient
