--[=[
	@class InfluxDBPointSettings
]=]

local InfluxDBPointSettings = {}
InfluxDBPointSettings.ClassName = "InfluxDBPointSettings"
InfluxDBPointSettings.__index = InfluxDBPointSettings

export type InfluxDBTags = { [string]: string }
export type ConvertTime = (number) -> number

function InfluxDBPointSettings.new()
	local self = setmetatable({}, InfluxDBPointSettings)

	self._defaultTags = {}
	self._convertTime = nil :: ConvertTime?

	return self
end

function InfluxDBPointSettings:SetDefaultTags(tags: InfluxDBTags)
	assert(type(tags) == "table", "Bad tags")

	for key, value in tags do
		assert(type(value) == "string", "Bad value")
		assert(type(key) == "string", "Bad key")
	end

	self._defaultTags = tags
end

function InfluxDBPointSettings:GetDefaultTags(): InfluxDBTags
	return self._defaultTags
end

function InfluxDBPointSettings:SetConvertTime(convertTime: ConvertTime?)
	assert(type(convertTime) == "function" or convertTime == nil, "Bad convertTime")

	self._convertTime = convertTime
end

function InfluxDBPointSettings:GetConvertTime(): ConvertTime?
	return self._convertTime
end


return InfluxDBPointSettings