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
		expect(InfluxDBEscapeUtils.measurement("hi")).to.equal("hi")
	end)

	it("should escape tabs", function()
		expect(InfluxDBEscapeUtils.measurement("\thi")).to.equal("\\thi")
	end)
end)

describe("InfluxDBEscapeUtils.quoted", function()
	it("should pass through fine", function()
		expect(InfluxDBEscapeUtils.quoted("hi")).to.equal("\"hi\"")
	end)

	it("should escape quotes", function()
		expect(InfluxDBEscapeUtils.quoted("\"hi")).to.equal("\"\\\"hi\"")
	end)
end)

describe("InfluxDBEscapeUtils.tag", function()
	it("should pass through fine", function()
		expect(InfluxDBEscapeUtils.tag("hi")).to.equal("hi")
	end)

	it("should escape tabs", function()
		expect(InfluxDBEscapeUtils.tag("\thi")).to.equal("\\thi")
	end)

	it("should escape =", function()
		expect(InfluxDBEscapeUtils.tag("=hi")).to.equal("\\=hi")
	end)

	it("should escape = and \\", function()
		expect(InfluxDBEscapeUtils.tag("\\=hi")).to.equal("\\\\\\=hi")
	end)

	it("should escape \\n", function()
		expect(InfluxDBEscapeUtils.tag("\nhi")).to.equal("\\nhi")
	end)
end)