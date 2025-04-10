--!strict
--[=[
	@class InfluxDBPoint
]=]

local require = require(script.Parent.loader).load(script)

local Math = require("Math")
local InfluxDBEscapeUtils = require("InfluxDBEscapeUtils")
local Table = require("Table")
local Set = require("Set")

local InfluxDBPoint = {}
InfluxDBPoint.ClassName = "InfluxDBPoint"
InfluxDBPoint.__index = InfluxDBPoint

export type InfluxDBPoint = typeof(setmetatable(
	{} :: {
		_measurementName: string?,
		_timestamp: (DateTime | string | number)?,
		_tags: { [string]: string },
		_fields: { [string]: string },
	},
	{} :: typeof({ __index = InfluxDBPoint })
))

export type InfluxDBPointTableData = {
	measurementName: string?,
	timestamp: (DateTime | string | number)?,
	tags: { [string]: string },
	fields: { [string]: string },
}

function InfluxDBPoint.new(measurementName: string?): InfluxDBPoint
	local self: InfluxDBPoint = setmetatable({} :: any, InfluxDBPoint)

	assert(type(measurementName) == "string" or measurementName == nil, "Bad measurementName")

	self._measurementName = measurementName
	self._timestamp = self:_convertTimeToMillis(nil)
	self._tags = {}
	self._fields = {}

	return self
end

function InfluxDBPoint.fromTableData(data: InfluxDBPointTableData)
	assert(type(data) == "table", "Bad data")
	assert(type(data.measurementName) == "string" or data.measurementName == nil, "Bad data.measurementName")

	local copy = InfluxDBPoint.new(data.measurementName)
	copy._timestamp = copy:_convertTimeToMillis(data.timestamp)

	if data.tags then
		assert(type(data.tags) == "table", "Bad data.tags")

		for tagKey, tagValue in data.tags do
			assert(type(tagKey) == "string", "Bad tagKey")
			assert(type(tagValue) == "string", "Bad tagValue")
		end

		copy._tags = data.tags
	end
	if data.fields then
		assert(type(data.fields) == "table", "Bad data.fields")

		for fieldKey, fieldValue in data.fields do
			assert(type(fieldKey) == "string", "Bad fieldKey")
			assert(type(fieldValue) == "string", "Bad fieldValue")

			-- TODO: Additional validation on fieldValue types
		end

		copy._fields = data.fields
	end

	return copy
end

function InfluxDBPoint.isInfluxDBPoint(point: any): boolean
	return type(point) == "table" and getmetatable(point) == InfluxDBPoint
end

function InfluxDBPoint.SetMeasurementName(self: InfluxDBPoint, name: string)
	assert(type(name) == "string" or name == nil, "Bad name")

	self._measurementName = name
end

function InfluxDBPoint.GetMeasurementName(self: InfluxDBPoint): string?
	return self._measurementName
end

function InfluxDBPoint.ToTableData(self: InfluxDBPoint): InfluxDBPointTableData
	return {
		measurementName = self._measurementName,
		timestamp = self._timestamp,
		tags = table.clone(self._tags),
		fields = table.clone(self._fields),
	}
end

--[=[
	If it's nil, the timestamp defaults to send time

	@param timestamp DateTime | nil
]=]
function InfluxDBPoint.SetTimestamp(self: InfluxDBPoint, timestamp: DateTime?)
	assert(typeof(timestamp) == "DateTime" or timestamp == nil, "Bad timestamp")

	self._timestamp = timestamp
end

--[=[
	Tags are indexed, whereas fields are not.

	@param tagKey string
	@param tagValue string
]=]
function InfluxDBPoint.AddTag(self: InfluxDBPoint, tagKey: string, tagValue: string)
	assert(type(tagKey) == "string", "Bad tagKey")
	assert(type(tagValue) == "string", "Bad tagValue")

	self._tags[tagKey] = tagValue
end

--[=[
	Adds an int field

	@param fieldName string
	@param value number
]=]
function InfluxDBPoint.AddIntField(self: InfluxDBPoint, fieldName: string, value: number)
	assert(type(fieldName) == "string", "Bad fieldName")
	assert(type(value) == "number", "Bad value")

	if Math.isNaN(value) or value <= -9223372036854776e3 or value >= 9223372036854776e3 then
		error(string.format("invalid integer value for field '%s': %d", fieldName, value))
	end

	if not Math.isFinite(value) then
		error(string.format("invalid integer value for field '%s': %d", fieldName, value))
	end

	self._fields[fieldName] = string.format("%di", value)
end

--[=[
	Adds a uint field

	@param fieldName string
	@param value number
]=]
function InfluxDBPoint.AddUintField(self: InfluxDBPoint, fieldName: string, value: number)
	assert(type(fieldName) == "string", "Bad fieldName")
	assert(type(value) == "number", "Bad value")

	if Math.isNaN(value) or value < 0 or value >= 9007199254740991 then
		error(string.format("invalid uint value for field '%s': %d", fieldName, value))
	end

	if not Math.isFinite(value) then
		error(string.format("invalid uint value for field '%s': %d", fieldName, value))
	end

	-- TODO: Support larger uint sizes
	self._fields[fieldName] = string.format("%du", value)
end

--[=[
	Adds a float field

	@param fieldName string
	@param value number
]=]
function InfluxDBPoint.AddFloatField(self: InfluxDBPoint, fieldName: string, value: number)
	assert(type(fieldName) == "string", "Bad fieldName")
	assert(type(value) == "number", "Bad value")

	if not Math.isFinite(value) then
		error(string.format("invalid float value for field '%s': %d", fieldName, value))
	end

	self._fields[fieldName] = tostring(value)
end

--[=[
	Adds a boolean field

	@param fieldName string
	@param value boolean
]=]
function InfluxDBPoint.AddBooleanField(self: InfluxDBPoint, fieldName: string, value: boolean)
	assert(type(fieldName) == "string", "Bad fieldName")
	assert(type(value) == "boolean", "Bad value")

	self._fields[fieldName] = value and "T" or "F"
end

--[=[
	Adds a string field

	@param fieldName string
	@param value string
]=]
function InfluxDBPoint.AddStringField(self: InfluxDBPoint, fieldName: string, value: string)
	assert(type(fieldName) == "string", "Bad fieldName")
	assert(type(value) == "string", "Bad value")

	self._fields[fieldName] = InfluxDBEscapeUtils.quoted(value)
end

function InfluxDBPoint.ToLineProtocol(self: InfluxDBPoint, pointSettings)
	if not self._measurementName then
		return nil
	end

	local fieldKeys = Table.keys(self._fields)
	table.sort(fieldKeys)

	local fields = {}
	for _, key in fieldKeys do
		local value = self._fields[key]
		table.insert(fields, InfluxDBEscapeUtils.tag(key) .. "=" .. value)
	end

	-- No fields
	if #fields == 0 then
		warn("[InfluxDBPoint] - Cannot transform point without fields")
		return nil
	end

	local tags = nil

	local defaultTags = pointSettings:GetDefaultTags()
	if next(defaultTags) or next(self._tags) then
		local tagKeysSet = table.clone(self._tags)
		for key, value in defaultTags do
			tagKeysSet[key] = value
		end
		local tagKeys = Set.toList(tagKeysSet)
		table.sort(tagKeys)

		tags = {}
		for _, key in tagKeys do
			local value = self._tags[key] or defaultTags[key]
			table.insert(tags, InfluxDBEscapeUtils.tag(key) .. "=" .. InfluxDBEscapeUtils.tag(value))
		end
	end

	local timestamp: any? = self._timestamp
	local convertTime = pointSettings:GetConvertTime()
	if convertTime then
		timestamp = convertTime(timestamp)
	else
		timestamp = self:_convertTimeToMillis(timestamp)
	end

	local tagsContent
	if tags then
		tagsContent = "," .. table.concat(tags, ",")
	else
		tagsContent = ""
	end

	return InfluxDBEscapeUtils.measurement(self._measurementName)
		.. tagsContent
		.. " "
		.. table.concat(fields, ",")
		.. " "
		.. tostring(timestamp)
end

function InfluxDBPoint._convertTimeToMillis(_self: InfluxDBPoint, value: (string | DateTime | number)?): string?
	if value == nil then
	    return tostring(DateTime.now().UnixTimestampMillis)
	elseif type(value) == "string" then
		if #value > 0 then
			return value
		else
			return nil
		end
	elseif typeof(value) == "DateTime" then
		return tostring(value.UnixTimestampMillis)
	elseif typeof(value) == "number" then
		return string.format("%0d", value)
	else
		return tostring(value)
	end
end

return InfluxDBPoint