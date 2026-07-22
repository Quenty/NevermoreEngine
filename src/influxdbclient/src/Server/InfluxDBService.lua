--!strict
--[=[
	Centralized service using serviceBag. Lets other packages share a single [InfluxDBClient] and, in
	tests, swap the underlying request implementation for an [InfluxDBRequestHandlerMock] at the
	ServiceBag layer -- the same pattern as [PlayerDataStoreService.SetRobloxDataStore].

	```lua
	-- Production
	local influxDBService = serviceBag:GetService(require("InfluxDBService"))
	-- ...after Init, before first use...
	influxDBService:SetClientConfig({ url = "https://example.com", token = "token" })

	local writeAPI = influxDBService:GetWriteAPI("org", "bucket")
	writeAPI:QueuePoint(point)
	```

	```lua
	-- Tests: inject a mock so nothing hits the network
	local requestMock = InfluxDBRequestHandlerMock.new()
	influxDBService:SetRequestHandler(requestMock.Handler)
	```

	@server
	@class InfluxDBService
]=]

local require = require(script.Parent.loader).load(script)

local InfluxDBClient = require("InfluxDBClient")
local InfluxDBClientConfigUtils = require("InfluxDBClientConfigUtils")
local InfluxDBWriteAPI = require("InfluxDBWriteAPI")
local Maid = require("Maid")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local InfluxDBService = {}
InfluxDBService.ServiceName = "InfluxDBService"

export type InfluxDBService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_client: InfluxDBClient.InfluxDBClient?,
		_requestHandler: InfluxDBWriteAPI.InfluxDBRequestHandler?,
		_pendingClientConfig: InfluxDBClientConfigUtils.InfluxDBClientConfig?,
	},
	{} :: typeof({ __index = InfluxDBService })
))

--[=[
	Initializes the InfluxDBService. Should be done via [ServiceBag.Init].

	@param serviceBag ServiceBag
]=]
function InfluxDBService.Init(self: InfluxDBService, serviceBag: ServiceBag.ServiceBag): ()
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()
end

--[=[
	Injects the request handler the underlying client uses to send data, instead of the real
	[HttpPromise.request]. Pass an [InfluxDBRequestHandlerMock] handler so tests never hit the network.
	Intended for testing; must be called before the client is first built.

	@param requestHandler InfluxDBRequestHandler
]=]
function InfluxDBService.SetRequestHandler(
	self: InfluxDBService,
	requestHandler: InfluxDBWriteAPI.InfluxDBRequestHandler
): ()
	assert(type(requestHandler) == "function", "Bad requestHandler")
	assert(not self._client, "Already built client, cannot override requestHandler")

	self._requestHandler = requestHandler
end

--[=[
	Sets the client config used to authenticate writes. May be called before or after the client is
	built; a later config is forwarded to the existing client.

	@param clientConfig InfluxDBClientConfig
]=]
function InfluxDBService.SetClientConfig(
	self: InfluxDBService,
	clientConfig: InfluxDBClientConfigUtils.InfluxDBClientConfig
): ()
	assert(InfluxDBClientConfigUtils.isClientConfig(clientConfig), "Bad clientConfig")

	self._pendingClientConfig = clientConfig

	if self._client then
		self._client:SetClientConfig(clientConfig)
	end
end

--[=[
	Returns the shared [InfluxDBClient], building it on first use with any injected request handler and
	client config.

	@return InfluxDBClient
]=]
function InfluxDBService.GetClient(self: InfluxDBService): InfluxDBClient.InfluxDBClient
	if self._client then
		return self._client
	end

	local client = self._maid:Add(InfluxDBClient.new(self._pendingClientConfig, self._requestHandler))
	self._client = client

	return client
end

--[=[
	Returns the write API for the given org and bucket from the shared client.

	@param org string
	@param bucket string
	@param precision string?
	@return InfluxDBWriteAPI
]=]
function InfluxDBService.GetWriteAPI(
	self: InfluxDBService,
	org: string,
	bucket: string,
	precision: string?
): InfluxDBWriteAPI.InfluxDBWriteAPI
	return self:GetClient():GetWriteAPI(org, bucket, precision)
end

--[=[
	Flushes every write API on the shared client. Resolves immediately if the client was never built.

	@return Promise<()>
]=]
function InfluxDBService.PromiseFlushAll(self: InfluxDBService): Promise.Promise<()>
	if not self._client then
		return Promise.resolved()
	end

	return self._client:PromiseFlushAll()
end

function InfluxDBService.Destroy(self: InfluxDBService): ()
	self._maid:DoCleaning()
end

return InfluxDBService
