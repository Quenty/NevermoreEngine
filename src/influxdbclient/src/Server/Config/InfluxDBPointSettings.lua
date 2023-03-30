--[=[
	@class InfluxDBPointSettings
]=]

local require = require(script.Parent.loader).load(script)

local InfluxDBPointSettings = {}
InfluxDBPointSettings.ClassName = "InfluxDBPointSettings"
InfluxDBPointSettings.__index = InfluxDBPointSettings

function InfluxDBPointSettings.new()
	local self = setmetatable({}, InfluxDBPointSettings)

	self._defaultTags = {}
	self._convertTime = nil

	return self
end

function InfluxDBPointSettings:SetDefaultTags(tags)
	assert(type(tags) == "table", "Bad tags")

	for key, value in pairs(tags) do
		assert(type(value) == "string", "Bad value")
		assert(type(key) == "string", "Bad key")
	end

	self._defaultTags = tags
end


function InfluxDBPointSettings:GetDefaultTags()
	return self._defaultTags
end

function InfluxDBPointSettings:SetConvertTime(convertTime)
	assert(type(convertTime) == "function", "Bad convertTime")

	self._convertTime = convertTime
end

function InfluxDBPointSettings:GetConvertTime()
	return self._convertTime
end


return InfluxDBPointSettings