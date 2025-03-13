--[=[
	@class InfluxDBClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local InfluxDBClientConfigUtils = require("InfluxDBClientConfigUtils")
local InfluxDBWriteAPI = require("InfluxDBWriteAPI")
local ValueObject = require("ValueObject")
local Maid = require("Maid")
local PromiseUtils = require("PromiseUtils")

local InfluxDBClient = setmetatable({}, BaseObject)
InfluxDBClient.ClassName = "InfluxDBClient"
InfluxDBClient.__index = InfluxDBClient

function InfluxDBClient.new(clientConfig)
	local self = setmetatable(BaseObject.new(), InfluxDBClient)

	self._clientConfig = self._maid:Add(ValueObject.new(nil))

	if clientConfig then
		self:SetClientConfig(clientConfig)
	end

	self._writeApis = {}

	return self
end

function InfluxDBClient:SetClientConfig(clientConfig)
	assert(InfluxDBClientConfigUtils.isClientConfig(clientConfig), "Bad clientConfig")

	self._clientConfig.Value = InfluxDBClientConfigUtils.createClientConfig(clientConfig)
end

function InfluxDBClient:GetWriteAPI(org, bucket, precision)
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

function InfluxDBClient:PromiseFlushAll()
	if self._flushAllPromises and self._flushAllPromises:IsPending() then
		return self._flushAllPromises
	end

	local promises = {}
	for _, bucketList in self._writeApis do
		for _, writeAPI in bucketList do
			table.insert(promises, writeAPI:PromiseFlush())
		end
	end

	self._flushAllPromises = PromiseUtils.all(promises)
	return self._flushAllPromises
end

return InfluxDBClient