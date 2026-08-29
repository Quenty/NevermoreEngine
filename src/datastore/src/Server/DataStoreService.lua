--!strict
--[=[
	Entry point for the datastore package. Registers every server-side datastore service, so a
	consumer gets the package in one [ServiceBag.GetService].

	@server
	@class DataStoreService
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")

local DataStoreService = {}
DataStoreService.ServiceName = "DataStoreService"

export type DataStoreService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = DataStoreService })
))

function DataStoreService.Init(self: DataStoreService, serviceBag: ServiceBag.ServiceBag)
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	-- External
	self._serviceBag:GetService(require("BindToCloseService"))
	self._serviceBag:GetService(require("PlaceMessagingService"))
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._serviceBag:GetService(require("DataStoreCmdrService"))
	self._serviceBag:GetService(require("GameDataStoreService"))
	self._serviceBag:GetService(require("PlayerDataStoreService"))
	self._serviceBag:GetService(require("PrivateServerDataStoreService"))
end

return DataStoreService
