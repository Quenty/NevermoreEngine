--!strict
--[[
	@class InfluxDBClient.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBClient = require("InfluxDBClient")
local InfluxDBPoint = require("InfluxDBPoint")
local InfluxDBRequestHandlerMock = require("InfluxDBRequestHandlerMock")
local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")

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

describe("InfluxDBClient.new", function()
	it("should construct without a config", function()
		local client = InfluxDBClient.new()
		expect(client.ClassName).toEqual("InfluxDBClient")
		client:Destroy()
	end)

	it("should construct with a config", function()
		local client = InfluxDBClient.new(CONFIG)
		expect(client.ClassName).toEqual("InfluxDBClient")
		client:Destroy()
	end)

	it("should throw when constructed with an invalid config", function()
		expect(function()
			InfluxDBClient.new({ url = "https://example.com" } :: any)
		end).toThrow("Bad clientConfig")
	end)

	it("should throw on a non-function, non-nil request handler", function()
		expect(function()
			InfluxDBClient.new(nil, 5 :: any)
		end).toThrow("Bad requestHandler")
	end)
end)

describe("InfluxDBClient.newMock", function()
	it("should return a client and a request handler mock", function()
		local client, requestMock = InfluxDBClient.newMock()

		expect(client.ClassName).toEqual("InfluxDBClient")
		expect(InfluxDBRequestHandlerMock.isInfluxDBRequestHandlerMock(requestMock)).toEqual(true)

		client:Destroy()
	end)

	it("should route write API traffic through the mock instead of the network", function()
		local client, requestMock = InfluxDBClient.newMock(CONFIG)

		local writeAPI = client:GetWriteAPI("my-org", "my-bucket")
		writeAPI:QueuePoint(newPoint())
		expect(PromiseTestUtils.awaitSettled(writeAPI:PromiseFlush())).toEqual(true)

		expect(#requestMock:GetRequests()).toEqual(1)
		expect((requestMock:GetLastRequest() :: any).Headers.Authorization).toEqual("Token my-token")

		client:Destroy()
	end)
end)

describe("InfluxDBClient.SetClientConfig", function()
	it("should throw on an invalid config", function()
		local client = InfluxDBClient.new()

		expect(function()
			client:SetClientConfig({ token = "my-token" } :: any)
		end).toThrow("Bad clientConfig")

		client:Destroy()
	end)
end)

describe("InfluxDBClient.GetWriteAPI", function()
	it("should throw on a non-string org", function()
		local client = InfluxDBClient.new()
		expect(function()
			client:GetWriteAPI(5 :: any, "my-bucket")
		end).toThrow("Bad org")
		client:Destroy()
	end)

	it("should throw on a non-string bucket", function()
		local client = InfluxDBClient.new()
		expect(function()
			client:GetWriteAPI("my-org", 5 :: any)
		end).toThrow("Bad bucket")
		client:Destroy()
	end)

	it("should throw on a non-string, non-nil precision", function()
		local client = InfluxDBClient.new()
		expect(function()
			client:GetWriteAPI("my-org", "my-bucket", 5 :: any)
		end).toThrow("Bad precision")
		client:Destroy()
	end)

	it("should return a write API", function()
		local client = InfluxDBClient.new()
		local writeAPI = client:GetWriteAPI("my-org", "my-bucket")
		expect(writeAPI.ClassName).toEqual("InfluxDBWriteAPI")
		client:Destroy()
	end)

	it("should return the same write API for the same org and bucket", function()
		local client = InfluxDBClient.new()
		local first = client:GetWriteAPI("my-org", "my-bucket")
		local second = client:GetWriteAPI("my-org", "my-bucket")
		expect(second).toBe(first)
		client:Destroy()
	end)

	it("should return a different write API for a different bucket", function()
		local client = InfluxDBClient.new()
		local first = client:GetWriteAPI("my-org", "bucket-a")
		local second = client:GetWriteAPI("my-org", "bucket-b")
		expect(second).never.toBe(first)
		client:Destroy()
	end)

	it("should return a different write API for a different org", function()
		local client = InfluxDBClient.new()
		local first = client:GetWriteAPI("org-a", "my-bucket")
		local second = client:GetWriteAPI("org-b", "my-bucket")
		expect(second).never.toBe(first)
		client:Destroy()
	end)

	it("should propagate the client config set before GetWriteAPI to the write API", function()
		local client, requestMock = InfluxDBClient.newMock(CONFIG)
		local writeAPI = client:GetWriteAPI("my-org", "my-bucket")

		writeAPI:QueuePoint(newPoint())
		expect(PromiseTestUtils.awaitSettled(writeAPI:PromiseFlush())).toEqual(true)

		expect(#requestMock:GetRequests()).toEqual(1)

		client:Destroy()
	end)

	it("should propagate a client config set after GetWriteAPI to the write API", function()
		local client, requestMock = InfluxDBClient.newMock()
		local writeAPI = client:GetWriteAPI("my-org", "my-bucket")

		client:SetClientConfig(CONFIG)

		writeAPI:QueuePoint(newPoint())
		expect(PromiseTestUtils.awaitSettled(writeAPI:PromiseFlush())).toEqual(true)

		expect(#requestMock:GetRequests()).toEqual(1)

		client:Destroy()
	end)
end)

describe("InfluxDBClient.PromiseFlushAll", function()
	it("should resolve when there are no write APIs", function()
		local client = InfluxDBClient.new()

		expect(PromiseTestUtils.awaitSettled(client:PromiseFlushAll())).toEqual(true)

		client:Destroy()
	end)

	it("should flush buffered points across every write API", function()
		local client, requestMock = InfluxDBClient.newMock(CONFIG)

		local apiA = client:GetWriteAPI("my-org", "bucket-a")
		local apiB = client:GetWriteAPI("my-org", "bucket-b")
		apiA:QueuePoint(newPoint())
		apiB:QueuePoint(newPoint())

		expect(PromiseTestUtils.awaitSettled(client:PromiseFlushAll())).toEqual(true)
		expect(#requestMock:GetRequests()).toEqual(2)

		client:Destroy()
	end)

	it("should reuse the pending flush promise while one is in flight", function()
		local client, requestMock = InfluxDBClient.newMock(CONFIG)

		requestMock:SetResponder(function()
			return Promise.new(function() end)
		end)

		local writeAPI = client:GetWriteAPI("my-org", "my-bucket")
		writeAPI:QueuePoint(newPoint())

		local first = client:PromiseFlushAll()
		local second = client:PromiseFlushAll()

		expect(second).toBe(first)

		-- Destroy cancels the in-flight request, rejecting this promise; consume it so the cancellation
		-- does not surface as an unhandled rejection.
		first:Catch(function() end)

		client:Destroy()
	end)
end)
