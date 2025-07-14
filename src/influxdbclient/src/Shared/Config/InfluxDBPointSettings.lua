--!strict
--[=[
	Holds settings for the InfluxDB point API

	@class InfluxDBPointSettings
]=]

local InfluxDBPointSettings = {}
InfluxDBPointSettings.ClassName = "InfluxDBPointSettings"
InfluxDBPointSettings.__index = InfluxDBPointSettings

export type InfluxDBTags = { [string]: string }
export type ConvertTime = ((DateTime | number | string)?) -> number

export type InfluxDBPointSettings = typeof(setmetatable(
	{} :: {
		_defaultTags: InfluxDBTags,
		_convertTime: ConvertTime?,
	},
	{} :: typeof({ __index = InfluxDBPointSettings })
))

--[=[
	Creates a new InfluxDB point settings

	@return InfluxDBPointSettings
]=]
function InfluxDBPointSettings.new(): InfluxDBPointSettings
	local self: InfluxDBPointSettings = setmetatable({} :: any, InfluxDBPointSettings)

	self._defaultTags = {}
	self._convertTime = nil :: ConvertTime?

	return self
end

--[=[
	Sets the default tags for the InfluxDB point settings

	@param tags InfluxDBTags
]=]
function InfluxDBPointSettings.SetDefaultTags(self: InfluxDBPointSettings, tags: InfluxDBTags): ()
	assert(type(tags) == "table", "Bad tags")

	for key, value in tags do
		assert(type(value) == "string", "Bad value")
		assert(type(key) == "string", "Bad key")
	end

	self._defaultTags = tags
end

--[=[
	Gets the default tags for the InfluxDB point settings

	@return InfluxDBTags
]=]
function InfluxDBPointSettings.GetDefaultTags(self: InfluxDBPointSettings): InfluxDBTags
	return self._defaultTags
end

--[=[
	Sets the conversion time function for the InfluxDB point settings

	@param convertTime (number) -> number
]=]
function InfluxDBPointSettings.SetConvertTime(self: InfluxDBPointSettings, convertTime: ConvertTime?)
	assert(type(convertTime) == "function" or convertTime == nil, "Bad convertTime")

	self._convertTime = convertTime
end

--[=[
	Gets the conversion time function for the InfluxDB point settings

	@return (number) -> number
]=]
function InfluxDBPointSettings.GetConvertTime(self: InfluxDBPointSettings): ConvertTime?
	return self._convertTime
end

return InfluxDBPointSettings
