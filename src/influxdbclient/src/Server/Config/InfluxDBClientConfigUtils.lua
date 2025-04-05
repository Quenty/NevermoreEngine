--[=[
	@class InfluxDBClientConfigUtils
]=]

local InfluxDBClientConfigUtils = {}

export type InfluxDBClientConfig = {
	url: string,
	token: string | Secret,
}

--[=[
	Checks if the given config is a valid InfluxDB client config

	@param config any
	@return boolean
]=]
function InfluxDBClientConfigUtils.isClientConfig(config: any): boolean
	return type(config) == "table"
		and type(config.url) == "string"
		and (typeof(config.token) == "string" or typeof(config.token) == "Secret")
end

--[=[
	Creates a new InfluxDB client config

	@param config InfluxDBClientConfig
	@return InfluxDBClientConfig
]=]
function InfluxDBClientConfigUtils.createClientConfig(config: InfluxDBClientConfig): InfluxDBClientConfig
	assert(InfluxDBClientConfigUtils.isClientConfig(config), "Bad config")

	return {
		url = config.url;
		token = config.token;
	}
end

return InfluxDBClientConfigUtils