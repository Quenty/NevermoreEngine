--[=[
	@class InfluxDBWriteOptionUtils
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

export type InfluxDBWriteOptions = {
	batchSize: number,
	maxBatchBytes: number,
	flushIntervalSeconds: number,
}

local InfluxDBWriteOptionUtils = {}

function InfluxDBWriteOptionUtils.getDefaultOptions(): InfluxDBWriteOptions
	return InfluxDBWriteOptionUtils.createWriteOptions({
		batchSize = 1000,
		maxBatchBytes = 50_000_000, -- default max batch size in the cloud
		flushIntervalSeconds = 60,
		-- maxRetries = 5;
		-- maxRetryTimeSeconds = 180;
		-- maxBufferLines = 32_000;
		-- retryJitterSeconds = 0.2;
		-- minRetryDelaySeconds = 5;
		-- maxRetryDelaySeconds = 125;
		-- exponentialBase = 2;
		-- randomRetry = true;
	})
end

function InfluxDBWriteOptionUtils.createWriteOptions(options: InfluxDBWriteOptions): InfluxDBWriteOptions
	assert(InfluxDBWriteOptionUtils.isWriteOptions(options), "Bad options")

	return Table.readonly(options)
end

function InfluxDBWriteOptionUtils.isWriteOptions(options: any): boolean
	return type(options) == "table"
		and type(options.batchSize) == "number"
		and type(options.maxBatchBytes) == "number"
		and type(options.flushIntervalSeconds) == "number"
		-- and type(options.maxRetries) == "number"
		-- and type(options.maxRetryTimeSeconds) == "number"
		-- and type(options.maxBufferLines) == "number"
		-- and type(options.retryJitterSeconds) == "number"
		-- and type(options.minRetryDelaySeconds) == "number"
		-- and type(options.maxRetryDelaySeconds) == "number"
		-- and type(options.exponentialBase) == "number"
		-- and type(options.randomRetry) == "boolean"
end

return InfluxDBWriteOptionUtils