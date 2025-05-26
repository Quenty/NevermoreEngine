--!strict
--[=[
	@class InfluxDBErrorUtils
]=]

local require = require(script.Parent.loader).load(script)

local JSONUtils = require("JSONUtils")

--[=[
	InfluxDB error type.
	@interface InfluxDBError
	.code string
	.message string
	@within InfluxDBErrorUtils
]=]
export type InfluxDBError = {
	code: string,
	message: string,
}

local InfluxDBErrorUtils = {}

--[=[
	Tries to parse the error body from InfluxDB.
	Returns nil if it fails to parse.

	@param body string
	@return InfluxDBError?
]=]
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

--[=[
	Checks if the given data is an InfluxDB error.

	@param data any
	@return boolean
]=]
function InfluxDBErrorUtils.isInfluxDBError(data: any): boolean
	return type(data) == "table" and type(data.code) == "string" and type(data.message) == "string"
end

return InfluxDBErrorUtils
