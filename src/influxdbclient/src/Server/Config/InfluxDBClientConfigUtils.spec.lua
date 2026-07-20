--!strict
--[[
	@class InfluxDBClientConfigUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBClientConfigUtils = require("InfluxDBClientConfigUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("InfluxDBClientConfigUtils.isClientConfig", function()
	it("should be true for a config with a string token", function()
		expect(InfluxDBClientConfigUtils.isClientConfig({
			url = "https://us-east-1-1.aws.cloud2.influxdata.com",
			token = "my-token",
		})).toEqual(true)
	end)

	it("should be false for a non-table", function()
		expect(InfluxDBClientConfigUtils.isClientConfig(nil)).toEqual(false)
		expect(InfluxDBClientConfigUtils.isClientConfig("str")).toEqual(false)
		expect(InfluxDBClientConfigUtils.isClientConfig(5)).toEqual(false)
	end)

	it("should be false when url is missing", function()
		expect(InfluxDBClientConfigUtils.isClientConfig({
			token = "my-token",
		})).toEqual(false)
	end)

	it("should be false when url is not a string", function()
		expect(InfluxDBClientConfigUtils.isClientConfig({
			url = 5,
			token = "my-token",
		})).toEqual(false)
	end)

	it("should be false when token is missing", function()
		expect(InfluxDBClientConfigUtils.isClientConfig({
			url = "https://example.com",
		})).toEqual(false)
	end)

	it("should be false when token is a number", function()
		expect(InfluxDBClientConfigUtils.isClientConfig({
			url = "https://example.com",
			token = 5,
		})).toEqual(false)
	end)
end)

describe("InfluxDBClientConfigUtils.createClientConfig", function()
	it("should return a config with only url and token fields", function()
		local config = InfluxDBClientConfigUtils.createClientConfig({
			url = "https://example.com",
			token = "my-token",
			extra = "ignored",
		} :: any)

		expect(config.url).toEqual("https://example.com")
		expect(config.token).toEqual("my-token")
		expect((config :: any).extra).toEqual(nil)
	end)

	it("should return a fresh table, not the same reference", function()
		local input = {
			url = "https://example.com",
			token = "my-token",
		}
		local config = InfluxDBClientConfigUtils.createClientConfig(input)

		expect(config).never.toBe(input)
	end)

	it("should throw on an invalid config", function()
		expect(function()
			InfluxDBClientConfigUtils.createClientConfig({
				token = "my-token",
			} :: any)
		end).toThrow("Bad config")
	end)
end)
