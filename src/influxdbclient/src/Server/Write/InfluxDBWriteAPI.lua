--[=[
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

function InfluxDBWriteAPI.new(org: string, bucket: string, precision: string?)
	local self = setmetatable(BaseObject.new(), InfluxDBWriteAPI)

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

function InfluxDBWriteAPI:SetPrintDebugWriteEnabled(printDebugEnabled: boolean)
	assert(type(printDebugEnabled) == "boolean", "Bad printDebugEnabled")

	self._printDebugWriteEnabled = printDebugEnabled
end

function InfluxDBWriteAPI:SetClientConfig(clientConfig: InfluxDBClientConfigUtils.InfluxDBClientConfig)
	assert(InfluxDBClientConfigUtils.isClientConfig(clientConfig), "Bad clientConfig")

	self._clientConfig.Value = InfluxDBClientConfigUtils.createClientConfig(clientConfig)
end

function InfluxDBWriteAPI:SetDefaultTags(tags)
	self._pointSettings:SetDefaultTags(tags)
end

function InfluxDBWriteAPI:SetConvertTime(convertTime)
	self._pointSettings:SetConvertTime(convertTime)
end

function InfluxDBWriteAPI:QueuePoint(point: InfluxDBPoint.InfluxDBPoint)
	assert(InfluxDBPoint.isInfluxDBPoint(point), "Bad point")

	local line = point:ToLineProtocol(self._pointSettings)
	if line then
		self._writeBuffer:Add(line)
	end

	if self._printDebugWriteEnabled then
		print(string.format("[InfluxDBWriteAPI.QueuePoint] - Queueing '%s'", line))
	end
end

function InfluxDBWriteAPI:QueuePoints(points: { InfluxDBPoint.InfluxDBPoint })
	assert(type(points) == "table", "Bad points")

	for _, point in points do
		assert(InfluxDBPoint.isInfluxDBPoint(point), "Bad point")

		local line = point:ToLineProtocol(self._pointSettings)
		if line then
			self._writeBuffer:Add(line)
		end

		if self._printDebugWriteEnabled then
			print(string.format("[InfluxDBWriteAPI.QueuePoints] - Queueing '%s'", line))
		end
	end
end

function InfluxDBWriteAPI:_promiseSendBatch(toSend: { InfluxDBPoint.InfluxDBPoint }): Promise.Promise<()>
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
	local request = {
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["Accept"] = "application/json",
			["Authorization"] = authHeader,
		},
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

function InfluxDBWriteAPI:PromiseFlush(): Promise.Promise<()>
	return self._writeBuffer:PromiseFlush()
end

function InfluxDBWriteAPI:_getWriteUrl(): string
	local config = self._clientConfig.Value
	local url = config.url

	assert(type(url) == "string", "Bad url")

	-- escape trailing slashes
	url = string.match(url, "(.-)[\\/]*$")

	return string.format("%s/api/v2/write?org=%s&bucket=%s&precision=%s",
		url,
		self._org,
		self._bucket,
		self._precision)
end

return InfluxDBWriteAPI