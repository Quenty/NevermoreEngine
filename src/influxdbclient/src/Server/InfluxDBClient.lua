--!strict
--[=[
	Client to write InfluxDB points to the server.

	@server
	@class InfluxDBClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local InfluxDBClientConfigUtils = require("InfluxDBClientConfigUtils")
local InfluxDBWriteAPI = require("InfluxDBWriteAPI")
local Maid = require("Maid")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local ValueObject = require("ValueObject")

local InfluxDBClient = setmetatable({}, BaseObject)
InfluxDBClient.ClassName = "InfluxDBClient"
InfluxDBClient.__index = InfluxDBClient

export type InfluxDBClient = typeof(setmetatable(
	{} :: {
		_clientConfig: ValueObject.ValueObject<InfluxDBClientConfigUtils.InfluxDBClientConfig>,
		_writeApis: { [string]: { [string]: InfluxDBWriteAPI.InfluxDBWriteAPI } },
		_flushAllPromises: Promise.Promise<()>,
	},
	{} :: typeof({ __index = InfluxDBClient })
)) & BaseObject.BaseObject

--[=[
	Creates a new InfluxDB client

	@param clientConfig InfluxDBClientConfig?
	@return InfluxDBClient
]=]
function InfluxDBClient.new(clientConfig: InfluxDBClientConfigUtils.InfluxDBClientConfig?): InfluxDBClient
	local self: InfluxDBClient = setmetatable(BaseObject.new() :: any, InfluxDBClient)

	self._clientConfig = self._maid:Add(ValueObject.new(nil))

	if clientConfig then
		self:SetClientConfig(clientConfig)
	end

	self._writeApis = {}

	return self
end

--[=[
	Sets the client config for this client

	@param clientConfig InfluxDBClientConfig
]=]
function InfluxDBClient.SetClientConfig(
	self: InfluxDBClient,
	clientConfig: InfluxDBClientConfigUtils.InfluxDBClientConfig
)
	assert(InfluxDBClientConfigUtils.isClientConfig(clientConfig), "Bad clientConfig")

	self._clientConfig.Value = InfluxDBClientConfigUtils.createClientConfig(clientConfig)
end

function InfluxDBClient.GetWriteAPI(
	self: InfluxDBClient,
	org: string,
	bucket: string,
	precision: string?
): InfluxDBWriteAPI.InfluxDBWriteAPI
	assert(self._clientConfig, "No self._clientConfig")
	assert(type(org) == "string", "Bad org")
	assert(type(bucket) == "string", "Bad bucket")
	assert(type(precision) == "string" or precision == nil, "Bad precision")

	self._writeApis[org] = self._writeApis[org] or {}
	if self._writeApis[org][bucket] then
		return self._writeApis[org][bucket]
	end

	local maid = Maid.new()

	local writeAPI = maid:Add(InfluxDBWriteAPI.new(org, bucket, precision))

	maid:GiveTask(self._clientConfig:Observe():Subscribe(function(clientConfig)
		writeAPI:SetClientConfig(clientConfig)
	end))

	maid:GiveTask(writeAPI.Destroying:Connect(function()
		self._maid[maid] = nil
	end))

	self._maid[maid] = maid

	-- TODO: On destroy flush
	maid:GiveTask(function()
		if self._writeApis[org] then
			if self._writeApis[org][bucket] == writeAPI then
				self._writeApis[org][bucket] = nil
			end
		end
	end)

	self._writeApis[org][bucket] = writeAPI

	-- TODO: Proxy
	return writeAPI
end

--[=[
	Flushes all write APIs. Returns a promise that resolves when all write APIs are flushed for all buckets.

	@return Promise<()>
]=]
function InfluxDBClient.PromiseFlushAll(self: InfluxDBClient): Promise.Promise<()>
	if self._flushAllPromises and self._flushAllPromises:IsPending() then
		return self._flushAllPromises
	end

	local promises = {}
	for _, bucketList in self._writeApis do
		for _, writeAPI: any in bucketList do
			table.insert(promises, writeAPI:PromiseFlush())
		end
	end

	self._flushAllPromises = PromiseUtils.all(promises)
	return self._flushAllPromises :: any
end

return InfluxDBClient
