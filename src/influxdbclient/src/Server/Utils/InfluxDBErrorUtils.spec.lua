--!strict
--[[
	@class InfluxDBErrorUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBErrorUtils = require("InfluxDBErrorUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("InfluxDBErrorUtils.isInfluxDBError", function()
	it("should be true for a table with string code and message", function()
		expect(InfluxDBErrorUtils.isInfluxDBError({
			code = "unauthorized",
			message = "unauthorized access",
		})).toEqual(true)
	end)

	it("should be false for a non-table", function()
		expect(InfluxDBErrorUtils.isInfluxDBError(nil)).toEqual(false)
		expect(InfluxDBErrorUtils.isInfluxDBError("str")).toEqual(false)
		expect(InfluxDBErrorUtils.isInfluxDBError(5)).toEqual(false)
	end)

	it("should be false when code is missing", function()
		expect(InfluxDBErrorUtils.isInfluxDBError({
			message = "unauthorized access",
		})).toEqual(false)
	end)

	it("should be false when message is not a string", function()
		expect(InfluxDBErrorUtils.isInfluxDBError({
			code = "unauthorized",
			message = 5,
		})).toEqual(false)
	end)
end)

describe("InfluxDBErrorUtils.tryParseErrorBody", function()
	it("should parse a valid InfluxDB error body", function()
		local errorBody =
			InfluxDBErrorUtils.tryParseErrorBody('{"code":"unauthorized","message":"unauthorized access"}')

		expect(errorBody).never.toEqual(nil)
		assert(errorBody, "no errorBody")
		expect(errorBody.code).toEqual("unauthorized")
		expect(errorBody.message).toEqual("unauthorized access")
	end)

	it("should return nil for a body that is not valid JSON", function()
		expect(InfluxDBErrorUtils.tryParseErrorBody("not json")).toEqual(nil)
	end)

	it("should return nil for valid JSON that is not an InfluxDB error", function()
		expect(InfluxDBErrorUtils.tryParseErrorBody('{"foo":"bar"}')).toEqual(nil)
	end)

	it("should return nil for a JSON array", function()
		expect(InfluxDBErrorUtils.tryParseErrorBody("[1, 2, 3]")).toEqual(nil)
	end)

	it("should return nil for an empty string", function()
		expect(InfluxDBErrorUtils.tryParseErrorBody("")).toEqual(nil)
	end)
end)
