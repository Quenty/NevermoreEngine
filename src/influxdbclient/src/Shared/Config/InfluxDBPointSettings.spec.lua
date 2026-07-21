--!strict
--[[
	@class InfluxDBPointSettings.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBPointSettings = require("InfluxDBPointSettings")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("InfluxDBPointSettings.new", function()
	it("should start with no default tags", function()
		local settings = InfluxDBPointSettings.new()

		expect(next(settings:GetDefaultTags())).toEqual(nil)
	end)

	it("should start with no convert time", function()
		local settings = InfluxDBPointSettings.new()

		expect(settings:GetConvertTime()).toEqual(nil)
	end)
end)

describe("InfluxDBPointSettings.SetDefaultTags", function()
	it("should store and return the tags", function()
		local settings = InfluxDBPointSettings.new()
		settings:SetDefaultTags({
			host = "server1",
			region = "us-east",
		})

		local tags = settings:GetDefaultTags()
		expect(tags.host).toEqual("server1")
		expect(tags.region).toEqual("us-east")
	end)

	it("should throw on a non-table", function()
		local settings = InfluxDBPointSettings.new()

		expect(function()
			settings:SetDefaultTags(5 :: any)
		end).toThrow("Bad tags")
	end)

	it("should throw when a tag value is not a string", function()
		local settings = InfluxDBPointSettings.new()

		expect(function()
			settings:SetDefaultTags({ host = 5 :: any })
		end).toThrow("Bad value")
	end)
end)

describe("InfluxDBPointSettings.SetConvertTime", function()
	it("should store and return the convert time function", function()
		local settings = InfluxDBPointSettings.new()
		local function convertTime(_value)
			return 42
		end
		settings:SetConvertTime(convertTime)

		expect(settings:GetConvertTime()).toBe(convertTime)
	end)

	it("should allow clearing the convert time with nil", function()
		local settings = InfluxDBPointSettings.new()
		settings:SetConvertTime(function(_value)
			return 42
		end)
		settings:SetConvertTime(nil)

		expect(settings:GetConvertTime()).toEqual(nil)
	end)

	it("should throw on a non-function", function()
		local settings = InfluxDBPointSettings.new()

		expect(function()
			settings:SetConvertTime(5 :: any)
		end).toThrow("Bad convertTime")
	end)
end)
