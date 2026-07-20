--!strict
--[[
	@class InfluxDBPoint.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBPoint = require("InfluxDBPoint")
local InfluxDBPointSettings = require("InfluxDBPointSettings")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- A fixed timestamp keeps line protocol output deterministic across tests.
local FIXED_TIMESTAMP = DateTime.fromUnixTimestampMillis(1600000000000)

local function newFixedPoint(measurementName: string?): InfluxDBPoint.InfluxDBPoint
	local point = InfluxDBPoint.new(measurementName)
	point:SetTimestamp(FIXED_TIMESTAMP)
	return point
end

describe("InfluxDBPoint.new", function()
	it("should default to an empty set of tags and fields", function()
		local point = InfluxDBPoint.new("temperature")
		local data = point:ToTableData()

		expect(next(data.tags)).toEqual(nil)
		expect(next(data.fields)).toEqual(nil)
	end)

	it("should allow a nil measurement name", function()
		local point = InfluxDBPoint.new()
		expect(point:GetMeasurementName()).toEqual(nil)
	end)

	it("should default the timestamp to a numeric millisecond string", function()
		local point = InfluxDBPoint.new("temperature")
		local timestamp = point:ToTableData().timestamp

		expect(type(timestamp)).toEqual("string")
		expect(tonumber(timestamp)).never.toEqual(nil)
	end)

	it("should throw on a non-string measurement name", function()
		expect(function()
			InfluxDBPoint.new(5 :: any)
		end).toThrow("Bad measurementName")
	end)
end)

describe("InfluxDBPoint.isInfluxDBPoint", function()
	it("should be true for a point", function()
		expect(InfluxDBPoint.isInfluxDBPoint(InfluxDBPoint.new("temperature"))).toEqual(true)
	end)

	it("should be false for a plain table", function()
		expect(InfluxDBPoint.isInfluxDBPoint({})).toEqual(false)
	end)

	it("should be false for nil and primitives", function()
		expect(InfluxDBPoint.isInfluxDBPoint(nil)).toEqual(false)
		expect(InfluxDBPoint.isInfluxDBPoint(5)).toEqual(false)
		expect(InfluxDBPoint.isInfluxDBPoint("str")).toEqual(false)
	end)
end)

describe("InfluxDBPoint measurement name", function()
	it("should get and set the measurement name", function()
		local point = InfluxDBPoint.new("temperature")
		expect(point:GetMeasurementName()).toEqual("temperature")

		point:SetMeasurementName("humidity")
		expect(point:GetMeasurementName()).toEqual("humidity")
	end)
end)

describe("InfluxDBPoint.AddTag", function()
	it("should throw on a non-string key", function()
		local point = InfluxDBPoint.new("temperature")
		expect(function()
			point:AddTag(5 :: any, "value")
		end).toThrow("Bad tagKey")
	end)

	it("should throw on a non-string value", function()
		local point = InfluxDBPoint.new("temperature")
		expect(function()
			point:AddTag("key", 5 :: any)
		end).toThrow("Bad tagValue")
	end)
end)

describe("InfluxDBPoint field setters", function()
	it("should add an int field with an 'i' suffix", function()
		local point = newFixedPoint("temperature")
		point:AddIntField("count", 5)

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual("temperature count=5i 1600000000000")
	end)

	it("should add a uint field with a 'u' suffix", function()
		local point = newFixedPoint("temperature")
		point:AddUintField("count", 5)

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual("temperature count=5u 1600000000000")
	end)

	it("should add a float field verbatim", function()
		local point = newFixedPoint("temperature")
		point:AddFloatField("value", 23.5)

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual("temperature value=23.5 1600000000000")
	end)

	it("should add a boolean field as T or F", function()
		local truePoint = newFixedPoint("temperature")
		truePoint:AddBooleanField("active", true)
		expect(truePoint:ToLineProtocol(InfluxDBPointSettings.new())).toEqual("temperature active=T 1600000000000")

		local falsePoint = newFixedPoint("temperature")
		falsePoint:AddBooleanField("active", false)
		expect(falsePoint:ToLineProtocol(InfluxDBPointSettings.new())).toEqual("temperature active=F 1600000000000")
	end)

	it("should add a quoted string field", function()
		local point = newFixedPoint("temperature")
		point:AddStringField("message", "hello")

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual('temperature message="hello" 1600000000000')
	end)

	it("should escape quotes in a string field value", function()
		local point = newFixedPoint("temperature")
		point:AddStringField("message", 'he said "hi"')

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual(
			'temperature message="he said \\"hi\\"" 1600000000000'
		)
	end)

	it("should throw on a non-number int value", function()
		local point = InfluxDBPoint.new("temperature")
		expect(function()
			point:AddIntField("count", "5" :: any)
		end).toThrow("Bad value")
	end)

	it("should throw on a NaN int value", function()
		local point = InfluxDBPoint.new("temperature")
		expect(function()
			point:AddIntField("count", 0 / 0)
		end).toThrow("invalid integer value")
	end)

	it("should throw on an out-of-range int value", function()
		local point = InfluxDBPoint.new("temperature")
		expect(function()
			point:AddIntField("count", 1e30)
		end).toThrow("invalid integer value")
	end)

	it("should throw on a negative uint value", function()
		local point = InfluxDBPoint.new("temperature")
		expect(function()
			point:AddUintField("count", -1)
		end).toThrow("invalid uint value")
	end)

	it("should throw on an out-of-range uint value", function()
		local point = InfluxDBPoint.new("temperature")
		expect(function()
			point:AddUintField("count", 9007199254740991)
		end).toThrow("invalid uint value")
	end)

	it("should throw on an infinite float value", function()
		local point = InfluxDBPoint.new("temperature")
		expect(function()
			point:AddFloatField("value", math.huge)
		end).toThrow("invalid float value")
	end)

	it("should throw on a non-boolean boolean value", function()
		local point = InfluxDBPoint.new("temperature")
		expect(function()
			point:AddBooleanField("active", "true" :: any)
		end).toThrow("Bad value")
	end)
end)

describe("InfluxDBPoint.ToLineProtocol", function()
	it("should return nil without a measurement name", function()
		local point = newFixedPoint()
		point:AddIntField("count", 5)

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual(nil)
	end)

	it("should return nil without any fields", function()
		local point = newFixedPoint("temperature")

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual(nil)
	end)

	it("should render tags before the field set", function()
		local point = newFixedPoint("temperature")
		point:AddTag("location", "office")
		point:AddFloatField("value", 23.5)

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual(
			"temperature,location=office value=23.5 1600000000000"
		)
	end)

	it("should sort field keys alphabetically", function()
		local point = newFixedPoint("temperature")
		point:AddIntField("zeta", 1)
		point:AddIntField("alpha", 2)

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual("temperature alpha=2i,zeta=1i 1600000000000")
	end)

	it("should sort tag keys alphabetically", function()
		local point = newFixedPoint("temperature")
		point:AddTag("zeta", "z")
		point:AddTag("alpha", "a")
		point:AddFloatField("value", 1)

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual(
			"temperature,alpha=a,zeta=z value=1 1600000000000"
		)
	end)

	it("should escape spaces in the measurement name", function()
		local point = newFixedPoint("my measurement")
		point:AddFloatField("value", 1)

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual("my\\ measurement value=1 1600000000000")
	end)

	it("should escape special characters in tag keys and values", function()
		local point = newFixedPoint("temperature")
		point:AddTag("my tag", "a,b")
		point:AddFloatField("value", 1)

		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual(
			"temperature,my\\ tag=a\\,b value=1 1600000000000"
		)
	end)

	it("should merge default tags from the point settings", function()
		local point = newFixedPoint("temperature")
		point:AddTag("location", "office")
		point:AddFloatField("value", 1)

		local settings = InfluxDBPointSettings.new()
		settings:SetDefaultTags({ host = "server1" })

		expect(point:ToLineProtocol(settings)).toEqual("temperature,host=server1,location=office value=1 1600000000000")
	end)

	it("should prefer the point's own tag over a default tag of the same key", function()
		local point = newFixedPoint("temperature")
		point:AddTag("host", "override")
		point:AddFloatField("value", 1)

		local settings = InfluxDBPointSettings.new()
		settings:SetDefaultTags({ host = "default" })

		expect(point:ToLineProtocol(settings)).toEqual("temperature,host=override value=1 1600000000000")
	end)

	it("should apply the convert time function to the timestamp", function()
		local point = newFixedPoint("temperature")
		point:AddFloatField("value", 1)

		local settings = InfluxDBPointSettings.new()
		settings:SetConvertTime(function(_timestamp)
			return 999
		end)

		expect(point:ToLineProtocol(settings)).toEqual("temperature value=1 999")
	end)
end)

describe("InfluxDBPoint.SetTimestamp", function()
	it("should throw on a non-DateTime, non-nil timestamp", function()
		local point = InfluxDBPoint.new("temperature")
		expect(function()
			point:SetTimestamp(5 :: any)
		end).toThrow("Bad timestamp")
	end)
end)

describe("InfluxDBPoint.ToTableData", function()
	it("should round-trip through fromTableData", function()
		local point = newFixedPoint("temperature")
		point:AddTag("location", "office")
		point:AddIntField("count", 5)

		local copy = InfluxDBPoint.fromTableData(point:ToTableData())

		expect(copy:GetMeasurementName()).toEqual("temperature")
		expect(copy:ToLineProtocol(InfluxDBPointSettings.new())).toEqual(
			point:ToLineProtocol(InfluxDBPointSettings.new())
		)
	end)

	it("should return clones that do not mutate the source point", function()
		local point = InfluxDBPoint.new("temperature")
		point:AddTag("location", "office")

		local data = point:ToTableData()
		data.tags.location = "mutated"

		expect(point:ToTableData().tags.location).toEqual("office")
	end)
end)

describe("InfluxDBPoint.fromTableData", function()
	it("should build a point from table data", function()
		local point = InfluxDBPoint.fromTableData({
			measurementName = "temperature",
			timestamp = 1600000000000,
			tags = { location = "office" },
			fields = { count = "5i" },
		})

		expect(point:GetMeasurementName()).toEqual("temperature")
		expect(point:ToLineProtocol(InfluxDBPointSettings.new())).toEqual(
			"temperature,location=office count=5i 1600000000000"
		)
	end)

	it("should throw on non-table data", function()
		expect(function()
			InfluxDBPoint.fromTableData(5 :: any)
		end).toThrow("Bad data")
	end)

	it("should throw on a non-string measurement name", function()
		expect(function()
			InfluxDBPoint.fromTableData({
				measurementName = 5 :: any,
				tags = {},
				fields = {},
			})
		end).toThrow("Bad data.measurementName")
	end)

	it("should throw on a non-string tag value", function()
		expect(function()
			InfluxDBPoint.fromTableData({
				measurementName = "temperature",
				tags = { location = 5 :: any },
				fields = {},
			})
		end).toThrow("Bad tagValue")
	end)

	it("should throw on a non-string field value", function()
		expect(function()
			InfluxDBPoint.fromTableData({
				measurementName = "temperature",
				tags = {},
				fields = { count = 5 :: any },
			})
		end).toThrow("Bad fieldValue")
	end)
end)
