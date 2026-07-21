--!strict
--[[
	@class InfluxDBWriteOptionUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBWriteOptionUtils = require("InfluxDBWriteOptionUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("InfluxDBWriteOptionUtils.getDefaultOptions", function()
	it("should return the documented defaults", function()
		local options = InfluxDBWriteOptionUtils.getDefaultOptions()

		expect(options.batchSize).toEqual(1000)
		expect(options.maxBatchBytes).toEqual(50_000_000)
		expect(options.flushIntervalSeconds).toEqual(60)
	end)

	it("should return a readonly table", function()
		local options = InfluxDBWriteOptionUtils.getDefaultOptions()

		expect(function()
			(options :: any).batchSize = 5
		end).toThrow()
	end)
end)

describe("InfluxDBWriteOptionUtils.isWriteOptions", function()
	it("should be true for a fully specified options table", function()
		expect(InfluxDBWriteOptionUtils.isWriteOptions({
			batchSize = 10,
			maxBatchBytes = 1000,
			flushIntervalSeconds = 5,
		})).toEqual(true)
	end)

	it("should be false for a non-table", function()
		expect(InfluxDBWriteOptionUtils.isWriteOptions(nil)).toEqual(false)
		expect(InfluxDBWriteOptionUtils.isWriteOptions("str")).toEqual(false)
	end)

	it("should be false when batchSize is missing", function()
		expect(InfluxDBWriteOptionUtils.isWriteOptions({
			maxBatchBytes = 1000,
			flushIntervalSeconds = 5,
		})).toEqual(false)
	end)

	it("should be false when maxBatchBytes is not a number", function()
		expect(InfluxDBWriteOptionUtils.isWriteOptions({
			batchSize = 10,
			maxBatchBytes = "1000",
			flushIntervalSeconds = 5,
		})).toEqual(false)
	end)

	it("should be false when flushIntervalSeconds is missing", function()
		expect(InfluxDBWriteOptionUtils.isWriteOptions({
			batchSize = 10,
			maxBatchBytes = 1000,
		})).toEqual(false)
	end)
end)

describe("InfluxDBWriteOptionUtils.createWriteOptions", function()
	it("should return a readonly copy of valid options", function()
		local options = InfluxDBWriteOptionUtils.createWriteOptions({
			batchSize = 10,
			maxBatchBytes = 1000,
			flushIntervalSeconds = 5,
		})

		expect(options.batchSize).toEqual(10)
		expect(options.maxBatchBytes).toEqual(1000)
		expect(options.flushIntervalSeconds).toEqual(5)

		expect(function()
			(options :: any).batchSize = 20
		end).toThrow()
	end)

	it("should throw on invalid options", function()
		expect(function()
			InfluxDBWriteOptionUtils.createWriteOptions({
				batchSize = 10,
			} :: any)
		end).toThrow("Bad options")
	end)
end)
