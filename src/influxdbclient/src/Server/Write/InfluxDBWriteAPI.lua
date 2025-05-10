--!strict
--[=[
	InfluxDB API to write to the server.

	@server
	@class InfluxDBWriteAPI
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local HttpPromise = require("HttpPromise")
local InfluxDBClientConfigUtils = require("InfluxDBClientConfigUtils")
local InfluxDBPoint = require("InfluxDBPoint")
local InfluxDBPointSettings = require("InfluxDBPointSettings")
local InfluxDBWriteBuffer = require("InfluxDBWriteBuffer")
local InfluxDBWriteOptionUtils = require("InfluxDBWriteOptionUtils")
local Promise = require("Promise")
local Signal = require("Signal")
local ValueObject = require("ValueObject")
local InfluxDBErrorUtils = require("InfluxDBErrorUtils")

local InfluxDBWriteAPI = setmetatable({}, BaseObject)
InfluxDBWriteAPI.ClassName = "InfluxDBWriteAPI"
InfluxDBWriteAPI.__index = InfluxDBWriteAPI

export type InfluxDBWriteAPI = typeof(setmetatable(
	{} :: {
		RequestFinished: Signal.Signal<(any)>,
		Destroying: Signal.Signal<()>,

		_clientConfig: ValueObject.ValueObject<InfluxDBClientConfigUtils.InfluxDBClientConfig>,
		_printDebugWriteEnabled: boolean,
		_org: string,
		_bucket: string,
		_precision: string,
		_pointSettings: InfluxDBPointSettings.InfluxDBPointSettings,
		_writeOptions: InfluxDBWriteOptionUtils.InfluxDBWriteOptions,
		_writeBuffer: InfluxDBWriteBuffer.InfluxDBWriteBuffer,
	},
	{} :: typeof({ __index = InfluxDBWriteAPI })
)) & BaseObject.BaseObject

--[=[
	Creates a new InfluxDB write API. Retrieve this from the [InfluxDBClient].

	@param org string
	@param bucket string
	@param precision string?
	@return InfluxDBWriteAPI
]=]
function InfluxDBWriteAPI.new(org: string, bucket: string, precision: string?): InfluxDBWriteAPI
	local self: InfluxDBWriteAPI = setmetatable(BaseObject.new() :: any, InfluxDBWriteAPI)

	assert(type(org) == "string", "Bad org")
	assert(type(bucket) == "string", "Bad bucket")
	assert(type(precision) == "string" or precision == nil, "Bad precision")

	self._clientConfig = self._maid:Add(ValueObject.new(nil))

	self._printDebugWriteEnabled = false
	self._org = org
	self._bucket = bucket
	self._precision = precision or "ms" -- we can default to ns in the future

	self._pointSettings = InfluxDBPointSettings.new()
	self._writeOptions = InfluxDBWriteOptionUtils.getDefaultOptions()

	self.RequestFinished = self._maid:Add(Signal.new())

	self.Destroying = Signal.new()
	self._maid:GiveTask(function()
		self.Destroying:Fire()
		self.Destroying:Destroy()
	end)

	self._writeBuffer = InfluxDBWriteBuffer.new(self._writeOptions, function(toSend)
		return self:_promiseSendBatch(toSend)
	end)
	self._maid:GiveTask(self._writeBuffer)

	return self
end

function InfluxDBWriteAPI.SetPrintDebugWriteEnabled(self: InfluxDBWriteAPI, printDebugEnabled: boolean): ()
	assert(type(printDebugEnabled) == "boolean", "Bad printDebugEnabled")

	self._printDebugWriteEnabled = printDebugEnabled
end

function InfluxDBWriteAPI.SetClientConfig(
	self: InfluxDBWriteAPI,
	clientConfig: InfluxDBClientConfigUtils.InfluxDBClientConfig
): ()
	assert(InfluxDBClientConfigUtils.isClientConfig(clientConfig), "Bad clientConfig")

	self._clientConfig.Value = InfluxDBClientConfigUtils.createClientConfig(clientConfig)
end

--[=[
	Sets the default tags to write with each point.

	@param tags InfluxDBTags
]=]
function InfluxDBWriteAPI.SetDefaultTags(self: InfluxDBWriteAPI, tags: InfluxDBPointSettings.InfluxDBTags): ()
	self._pointSettings:SetDefaultTags(tags)
end

--[=[
	Sets the conversion time

	@param convertTime (number) -> number
]=]
function InfluxDBWriteAPI.SetConvertTime(self: InfluxDBWriteAPI, convertTime: InfluxDBPointSettings.ConvertTime?): ()
	self._pointSettings:SetConvertTime(convertTime)
end

--[=[
	Queues a new influx DB point to send to the server.

	@param point InfluxDBPoint
]=]
function InfluxDBWriteAPI.QueuePoint(self: InfluxDBWriteAPI, point: InfluxDBPoint.InfluxDBPoint): ()
	assert(InfluxDBPoint.isInfluxDBPoint(point), "Bad point")

	local line = point:ToLineProtocol(self._pointSettings)
	if line then
		self._writeBuffer:Add(line)
	end

	if self._printDebugWriteEnabled then
		print(string.format("[InfluxDBWriteAPI.QueuePoint] - Queueing '%s'", line or "nil"))
	end
end

--[=[
	Queues a new list of influx DB points to send to the server.

	@param points { InfluxDBPoint }
]=]
function InfluxDBWriteAPI.QueuePoints(self: InfluxDBWriteAPI, points: { InfluxDBPoint.InfluxDBPoint }): ()
	assert(type(points) == "table", "Bad points")

	for _, point in points do
		assert(InfluxDBPoint.isInfluxDBPoint(point), "Bad point")

		local line = point:ToLineProtocol(self._pointSettings)
		if line then
			self._writeBuffer:Add(line)
		end

		if self._printDebugWriteEnabled then
			print(string.format("[InfluxDBWriteAPI.QueuePoints] - Queueing '%s'", line or "nil"))
		end
	end
end

function InfluxDBWriteAPI._promiseSendBatch(self: InfluxDBWriteAPI, toSend: { string }): Promise.Promise<()>
	assert(type(toSend) == "table", "Bad toSend")

	local clientConfig = self._clientConfig.Value
	if not clientConfig then
		return Promise.rejected("No client configuration")
	end

	-- Transform to "Token %s".
	local authHeader: string | Secret
	if typeof(clientConfig.token) == "string" and #clientConfig.token > 0 then
		authHeader = "Token " .. clientConfig.token
	elseif typeof(clientConfig.token) == "Secret" then
		authHeader = clientConfig.token:AddPrefix("Token ")
	else
		error("Bad clientConfig.token")
	end

	local body = table.concat(toSend, "\n")
	local request: HttpPromise.HTTPRequest = {
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
			["Authorization"] = authHeader,
		} :: any,
		Compress = Enum.HttpCompression.Gzip,
		Url = self:_getWriteUrl(),
		Body = body,
	}

	if self._printDebugWriteEnabled then
		print(string.format("[InfluxDBWriteAPI._promiseSendBatch] - Sending data %s", body))
	end

	return self._maid
		:GivePromise(HttpPromise.request(request))
		:Then(function(result)
			if result.Success then
				if self.Destroy then
					self.RequestFinished:Fire(result)
				end

				return true
			else
				return Promise.rejected(result)
			end
		end)
		:Catch(function(err)
			if self.Destroy then
				self.RequestFinished:Fire(err)
			end

			if HttpPromise.isHttpResponse(err) then
				local errorBody = InfluxDBErrorUtils.tryParseErrorBody(err.Body)

				if errorBody then
					local message = string.format(
						"[InfluxDBWriteAPI:QueuePoint] - %d: %s - %s",
						err.StatusCode,
						errorBody.code,
						errorBody.message
					)
					warn(message)

					return Promise.rejected(errorBody)
				end

				warn(
					string.format(
						"[InfluxDBWriteAPI:QueuePoint] - %d: %s - %s",
						err.StatusCode,
						err.StatusMessage,
						tostring(err.Body)
					)
				)

				return Promise.rejected(
					string.format("[InfluxDBWriteAPI:QueuePoint] - %d: %s", err.StatusCode, err.StatusMessage)
				)
			else
				return Promise.rejected(err or "Request got cancelled")
			end
		end)
end

function InfluxDBWriteAPI.PromiseFlush(self: InfluxDBWriteAPI): Promise.Promise<()>
	return self._writeBuffer:PromiseFlush()
end

function InfluxDBWriteAPI._getWriteUrl(self: InfluxDBWriteAPI): string
	local config = self._clientConfig.Value
	local url: string = config.url

	assert(type(url) == "string", "Bad url")

	-- escape trailing slashes
	url = string.match(url, "(.-)[\\/]*$") or ""

	return string.format("%s/api/v2/write?org=%s&bucket=%s&precision=%s",
		url,
		self._org,
		self._bucket,
		self._precision)
end

return InfluxDBWriteAPI