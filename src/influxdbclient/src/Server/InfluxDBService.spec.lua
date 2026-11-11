--!strict
--[[
	@class InfluxDBService.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBPoint = require("InfluxDBPoint")
local InfluxDBRequestHandlerMock = require("InfluxDBRequestHandlerMock")
local InfluxDBService = require("InfluxDBService")
local Jest = require("Jest")
local PromiseTestUtils = require("PromiseTestUtils")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local FIXED_TIMESTAMP = DateTime.fromUnixTimestampMillis(1600000000000)

local CONFIG = {
	url = "https://example.com",
	token = "my-token",
}

local function newPoint(): InfluxDBPoint.InfluxDBPoint
	local point = InfluxDBPoint.new("temperature")
	point:SetTimestamp(FIXED_TIMESTAMP)
	point:AddFloatField("value", 23.5)
	return point
end

local function setup()
	local serviceBag = ServiceBag.new()
	local influxDBService: InfluxDBService.InfluxDBService = serviceBag:GetService(InfluxDBService) :: any
	serviceBag:Init()

	local requestMock = InfluxDBRequestHandlerMock.new()
	influxDBService:SetRequestHandler(requestMock.Handler)

	serviceBag:Start()

	return serviceBag, influxDBService, requestMock
end

describe("InfluxDBService.SetRequestHandler", function()
	it("should route write traffic through the injected mock", function()
		local serviceBag, influxDBService, requestMock = setup()
		influxDBService:SetClientConfig(CONFIG)

		local writeAPI = influxDBService:GetWriteAPI("my-org", "my-bucket")
		writeAPI:QueuePoint(newPoint())
		expect(PromiseTestUtils.awaitSettled(writeAPI:PromiseFlush())).toEqual(true)

		expect(#requestMock:GetRequests()).toEqual(1)
		expect((requestMock:GetLastRequest() :: any).Headers.Authorization).toEqual("Token my-token")

		serviceBag:Destroy()
	end)

	it("should throw on a non-function handler", function()
		local serviceBag = ServiceBag.new()
		local influxDBService: InfluxDBService.InfluxDBService = serviceBag:GetService(InfluxDBService) :: any
		serviceBag:Init()

		expect(function()
			influxDBService:SetRequestHandler(5 :: any)
		end).toThrow("Bad requestHandler")

		serviceBag:Destroy()
	end)

	it("should throw once the client has been built", function()
		local serviceBag = ServiceBag.new()
		local influxDBService: InfluxDBService.InfluxDBService = serviceBag:GetService(InfluxDBService) :: any
		serviceBag:Init()
		serviceBag:Start()

		influxDBService:GetClient()

		expect(function()
			influxDBService:SetRequestHandler(InfluxDBRequestHandlerMock.new().Handler)
		end).toThrow("Already built client")

		serviceBag:Destroy()
	end)
end)

describe("InfluxDBService.SetClientConfig", function()
	it("should throw on an invalid config", function()
		local serviceBag, influxDBService = setup()

		expect(function()
			influxDBService:SetClientConfig({ url = "https://example.com" } :: any)
		end).toThrow("Bad clientConfig")

		serviceBag:Destroy()
	end)

	it("should apply a config set after the client is built", function()
		local serviceBag, influxDBService, requestMock = setup()

		local writeAPI = influxDBService:GetWriteAPI("my-org", "my-bucket")

		influxDBService:SetClientConfig(CONFIG)

		writeAPI:QueuePoint(newPoint())
		expect(PromiseTestUtils.awaitSettled(writeAPI:PromiseFlush())).toEqual(true)

		expect(#requestMock:GetRequests()).toEqual(1)

		serviceBag:Destroy()
	end)
end)

describe("InfluxDBService.GetClient", function()
	it("should return the same client across calls", function()
		local serviceBag, influxDBService = setup()

		expect(influxDBService:GetClient()).toBe(influxDBService:GetClient())

		serviceBag:Destroy()
	end)
end)

describe("InfluxDBService.PromiseFlushAll", function()
	it("should resolve when the client was never built", function()
		local serviceBag, influxDBService = setup()

		expect(PromiseTestUtils.awaitSettled(influxDBService:PromiseFlushAll())).toEqual(true)

		serviceBag:Destroy()
	end)

	it("should flush buffered points once the client is built", function()
		local serviceBag, influxDBService, requestMock = setup()
		influxDBService:SetClientConfig(CONFIG)

		local writeAPI = influxDBService:GetWriteAPI("my-org", "my-bucket")
		writeAPI:QueuePoint(newPoint())

		expect(PromiseTestUtils.awaitSettled(influxDBService:PromiseFlushAll())).toEqual(true)
		expect(#requestMock:GetRequests()).toEqual(1)

		serviceBag:Destroy()
	end)
end)
