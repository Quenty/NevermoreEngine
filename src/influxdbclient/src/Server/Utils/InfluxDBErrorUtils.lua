--[=[
	@class InfluxDBErrorUtils
]=]

local require = require(script.Parent.loader).load(script)

local JSONUtils = require("JSONUtils")

export type InfluxDBError = {
	code: string,
	message: string,
}

local InfluxDBErrorUtils = {}

function InfluxDBErrorUtils.tryParseErrorBody(body: string): InfluxDBError?
	local ok, decoded, _err = JSONUtils.jsonDecode(body)
	if not ok then
		return nil
	end

	if InfluxDBErrorUtils.isInfluxDBError(decoded) then
		return decoded :: any
	else
		return nil
	end
end

function InfluxDBErrorUtils.isInfluxDBError(data: any): boolean
	return type(data) == "table"
		and type(data.code) == "string"
		and type(data.message) == "string"
end

return InfluxDBErrorUtils