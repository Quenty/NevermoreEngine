--[[
	@class InfluxDBEscapeUtils.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local InfluxDBEscapeUtils = require("InfluxDBEscapeUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("InfluxDBEscapeUtils.measurement", function()
	it("should pass through fine", function()
		local measurement = InfluxDBEscapeUtils.measurement("hi")
		expect(measurement).toBe("hi")
	end)

	it("should escape tabs", function()
		local measurement = InfluxDBEscapeUtils.measurement("\thi")
		expect(measurement).toBe("\\thi")
	end)
end)

describe("InfluxDBEscapeUtils.quoted", function()
	it("should pass through fine", function()
		expect(InfluxDBEscapeUtils.quoted("hi")).toBe("\"hi\"")
	end)

	it("should escape quotes", function()
		expect(InfluxDBEscapeUtils.quoted("\"hi")).toBe("\"\\\"hi\"")
	end)
end)

describe("InfluxDBEscapeUtils.tag", function()
	it("should pass through fine", function()
		local tag = InfluxDBEscapeUtils.tag("hi")
		expect(tag).toBe("hi")
	end)

	it("should escape tabs", function()
		local tag = InfluxDBEscapeUtils.tag("\thi")
		expect(tag).toBe("\\thi")
	end)

	it("should escape =", function()
		local tag = InfluxDBEscapeUtils.tag("=hi")
		expect(tag).toBe("\\=hi")
	end)

	it("should escape = and \\", function()
		local tag = InfluxDBEscapeUtils.tag("\\=hi")
		expect(tag).toBe("\\\\\\=hi")
	end)

	it("should escape \\n", function()
		local tag = InfluxDBEscapeUtils.tag("\nhi")
		expect(tag).toBe("\\nhi")
	end)
end)