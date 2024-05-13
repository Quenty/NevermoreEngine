--[=[
	@class InfluxDBClientConfigUtils
]=]

local InfluxDBClientConfigUtils = {}

function InfluxDBClientConfigUtils.isClientConfig(config)
	return type(config) == "table"
		and type(config.url) == "string"
		and (typeof(config.token) == "string" or typeof(config.token) == "Secret")
end

function InfluxDBClientConfigUtils.createClientConfig(config)
	assert(InfluxDBClientConfigUtils.isClientConfig(config), "Bad config")

	return {
		url = config.url;
		token = config.token;
	}
end

return InfluxDBClientConfigUtils