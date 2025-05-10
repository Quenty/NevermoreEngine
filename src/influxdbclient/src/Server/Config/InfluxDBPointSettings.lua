--!strict
--[=[
	@class InfluxDBPointSettings
]=]

local InfluxDBPointSettings = {}
InfluxDBPointSettings.ClassName = "InfluxDBPointSettings"
InfluxDBPointSettings.__index = InfluxDBPointSettings

export type InfluxDBTags = { [string]: string }
export type ConvertTime = (number) -> number

export type InfluxDBPointSettings = typeof(setmetatable(
	{} :: {
		_defaultTags: InfluxDBTags,
		_convertTime: ConvertTime?,
	},
	{} :: typeof({ __index = InfluxDBPointSettings })
))

function InfluxDBPointSettings.new(): InfluxDBPointSettings
	local self: InfluxDBPointSettings = setmetatable({} :: any, InfluxDBPointSettings)

	self._defaultTags = {}
	self._convertTime = nil :: ConvertTime?

	return self
end

function InfluxDBPointSettings.SetDefaultTags(self: InfluxDBPointSettings, tags: InfluxDBTags): ()
	assert(type(tags) == "table", "Bad tags")

	for key, value in tags do
		assert(type(value) == "string", "Bad value")
		assert(type(key) == "string", "Bad key")
	end

	self._defaultTags = tags
end

function InfluxDBPointSettings.GetDefaultTags(self: InfluxDBPointSettings): InfluxDBTags
	return self._defaultTags
end

function InfluxDBPointSettings.SetConvertTime(self: InfluxDBPointSettings, convertTime: ConvertTime?)
	assert(type(convertTime) == "function" or convertTime == nil, "Bad convertTime")

	self._convertTime = convertTime
end

function InfluxDBPointSettings.GetConvertTime(self: InfluxDBPointSettings): ConvertTime?
	return self._convertTime
end


return InfluxDBPointSettings