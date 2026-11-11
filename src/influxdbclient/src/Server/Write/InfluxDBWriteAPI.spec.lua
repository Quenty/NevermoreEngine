--!strict
--[[
	@class InfluxDBWriteAPI.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBPoint = require("InfluxDBPoint")
local InfluxDBRequestHandlerMock = require("InfluxDBRequestHandlerMock")
local InfluxDBWriteAPI = require("InfluxDBWriteAPI")
local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- A fixed timestamp keeps the emitted line protocol (and therefore the request body) deterministic.
local FIXED_TIMESTAMP = DateTime.fromUnixTimestampMillis(1600000000000)

local function newPoint(): InfluxDBPoint.InfluxDBPoint
	local point = InfluxDBPoint.new("temperature")
	point:SetTimestamp(FIXED_TIMESTAMP)
	point:AddFloatField("value", 23.5)
	return point
end

-- Line protocol produced by newPoint() with default (empty) point settings.
local POINT_LINE = "temperature value=23.5 1600000000000"

-- Builds a write API wired to a request mock (so nothing hits the network) with a client config set.
local function newConfiguredAPI(configOverrides: { [string]: any }?)
	local mock = InfluxDBRequestHandlerMock.new()
	local api = InfluxDBWriteAPI.new("my-org", "my-bucket", nil, mock.Handler)

	local config = {
		url = "https://example.com",
		token = "my-token",
	}
	for key, value in configOverrides or ({} :: { [string]: any }) do
		config[key] = value
	end
	api:SetClientConfig(config)

	return api, mock
end

describe("InfluxDBWriteAPI.new", function()
	it("should default the precision to ms in the write url", function()
		local api, mock = newConfiguredAPI()
		api:QueuePoint(newPoint())
		expect(PromiseTestUtils.awaitSettled(api:PromiseFlush())).toEqual(true)

		expect((mock:GetLastRequest() :: any).Url).toEqual(
			"https://example.com/api/v2/write?org=my-org&bucket=my-bucket&precision=ms"
		)

		api:Destroy()
	end)

	it("should use a provided precision in the write url", function()
		local mock = InfluxDBRequestHandlerMock.new()
		local api = InfluxDBWriteAPI.new("my-org", "my-bucket", "ns", mock.Handler)
		api:SetClientConfig({ url = "https://example.com", token = "my-token" })
		api:QueuePoint(newPoint())
		expect(PromiseTestUtils.awaitSettled(api:PromiseFlush())).toEqual(true)

		expect((mock:GetLastRequest() :: any).Url).toEqual(
			"https://example.com/api/v2/write?org=my-org&bucket=my-bucket&precision=ns"
		)

		api:Destroy()
	end)

	it("should throw on a non-string org", function()
		expect(function()
			InfluxDBWriteAPI.new(5 :: any, "my-bucket")
		end).toThrow("Bad org")
	end)

	it("should throw on a non-string bucket", function()
		expect(function()
			InfluxDBWriteAPI.new("my-org", 5 :: any)
		end).toThrow("Bad bucket")
	end)

	it("should throw on a non-string, non-nil precision", function()
		expect(function()
			InfluxDBWriteAPI.new("my-org", "my-bucket", 5 :: any)
		end).toThrow("Bad precision")
	end)

	it("should throw on a non-function, non-nil request handler", function()
		expect(function()
			InfluxDBWriteAPI.new("my-org", "my-bucket", nil, 5 :: any)
		end).toThrow("Bad requestHandler")
	end)
end)

describe("InfluxDBWriteAPI.SetClientConfig", function()
	it("should throw on an invalid config", function()
		local api = InfluxDBWriteAPI.new("my-org", "my-bucket")

		expect(function()
			api:SetClientConfig({ url = "https://example.com" } :: any)
		end).toThrow("Bad clientConfig")

		api:Destroy()
	end)
end)

describe("InfluxDBWriteAPI.SetPrintDebugWriteEnabled", function()
	it("should throw on a non-boolean value", function()
		local api = InfluxDBWriteAPI.new("my-org", "my-bucket")

		expect(function()
			api:SetPrintDebugWriteEnabled("yes" :: any)
		end).toThrow("Bad printDebugEnabled")

		api:Destroy()
	end)
end)

describe("InfluxDBWriteAPI.QueuePoint", function()
	it("should throw on a non-point", function()
		local api = InfluxDBWriteAPI.new("my-org", "my-bucket")

		expect(function()
			api:QueuePoint({} :: any)
		end).toThrow("Bad point")

		api:Destroy()
	end)

	it("should not send a request until flushed", function()
		local api, mock = newConfiguredAPI()
		api:QueuePoint(newPoint())

		expect(#mock:GetRequests()).toEqual(0)

		api:Destroy()
	end)
end)

describe("InfluxDBWriteAPI.QueuePoints", function()
	it("should throw on a non-table", function()
		local api = InfluxDBWriteAPI.new("my-org", "my-bucket")

		expect(function()
			api:QueuePoints("nope" :: any)
		end).toThrow("Bad points")

		api:Destroy()
	end)

	it("should throw on a non-point entry in the list", function()
		local api = InfluxDBWriteAPI.new("my-org", "my-bucket")

		expect(function()
			api:QueuePoints({ {} :: any })
		end).toThrow("Bad point")

		api:Destroy()
	end)

	it("should batch every queued point into a single newline-joined body", function()
		local api, mock = newConfiguredAPI()
		api:QueuePoints({ newPoint(), newPoint() })
		expect(PromiseTestUtils.awaitSettled(api:PromiseFlush())).toEqual(true)

		expect(#mock:GetRequests()).toEqual(1)
		expect((mock:GetLastRequest() :: any).Body).toEqual(POINT_LINE .. "\n" .. POINT_LINE)

		api:Destroy()
	end)
end)

describe("InfluxDBWriteAPI.PromiseFlush", function()
	it("should reject with no client configuration when none is set", function()
		local mock = InfluxDBRequestHandlerMock.new()
		local api = InfluxDBWriteAPI.new("my-org", "my-bucket", nil, mock.Handler)
		api:QueuePoint(newPoint())

		local outcome, payload = PromiseTestUtils.awaitOutcome(api:PromiseFlush())
		expect(outcome).toEqual("rejected")
		expect(payload).toEqual("No client configuration")
		-- The batch is abandoned before a request is ever built.
		expect(#mock:GetRequests()).toEqual(0)

		api:Destroy()
	end)

	it("should send the buffered line protocol as the request body", function()
		local api, mock = newConfiguredAPI()
		api:QueuePoint(newPoint())
		expect(PromiseTestUtils.awaitSettled(api:PromiseFlush())).toEqual(true)

		expect((mock:GetLastRequest() :: any).Method).toEqual("POST")
		expect((mock:GetLastRequest() :: any).Body).toEqual(POINT_LINE)

		api:Destroy()
	end)

	it("should send a Token-prefixed authorization header for a string token", function()
		local api, mock = newConfiguredAPI()
		api:QueuePoint(newPoint())
		expect(PromiseTestUtils.awaitSettled(api:PromiseFlush())).toEqual(true)

		expect((mock:GetLastRequest() :: any).Headers.Authorization).toEqual("Token my-token")

		api:Destroy()
	end)

	it("should strip a trailing slash from the configured url", function()
		local api, mock = newConfiguredAPI({ url = "https://example.com/" })
		api:QueuePoint(newPoint())
		expect(PromiseTestUtils.awaitSettled(api:PromiseFlush())).toEqual(true)

		expect((mock:GetLastRequest() :: any).Url).toEqual(
			"https://example.com/api/v2/write?org=my-org&bucket=my-bucket&precision=ms"
		)

		api:Destroy()
	end)

	it("should resolve and fire RequestFinished on a successful response", function()
		local api, mock = newConfiguredAPI()

		local response = {
			Success = true,
			StatusCode = 204,
			StatusMessage = "No Content",
			Headers = {},
			Body = "",
		}
		mock:SetResponder(function()
			return Promise.resolved(response)
		end)

		local finished = {}
		api.RequestFinished:Connect(function(result)
			table.insert(finished, result)
		end)

		api:QueuePoint(newPoint())
		local outcome = PromiseTestUtils.awaitOutcome(api:PromiseFlush())

		expect(outcome).toEqual("resolved")
		expect(finished[1]).toBe(response)

		api:Destroy()
	end)

	it("should reject with the parsed InfluxDB error when the body is a known error", function()
		local api, mock = newConfiguredAPI()
		mock:SetResponder(function()
			return Promise.rejected({
				Success = false,
				StatusCode = 401,
				StatusMessage = "Unauthorized",
				Headers = {},
				Body = '{"code":"unauthorized","message":"token required"}',
			})
		end)

		api:QueuePoint(newPoint())

		local outcome, payload = PromiseTestUtils.awaitOutcome(api:PromiseFlush())
		expect(outcome).toEqual("rejected")
		expect(payload.code).toEqual("unauthorized")
		expect(payload.message).toEqual("token required")

		api:Destroy()
	end)

	it("should reject with a formatted string when the error body is not a known error", function()
		local api, mock = newConfiguredAPI()
		mock:SetResponder(function()
			return Promise.rejected({
				Success = false,
				StatusCode = 500,
				StatusMessage = "Internal Server Error",
				Headers = {},
				Body = "not json",
			})
		end)

		api:QueuePoint(newPoint())

		local outcome, payload = PromiseTestUtils.awaitOutcome(api:PromiseFlush())
		expect(outcome).toEqual("rejected")
		expect(type(payload)).toEqual("string")
		expect(string.find(payload, "500", 1, true) ~= nil).toEqual(true)

		api:Destroy()
	end)

	it("should reject with the raw error when it is not an http response", function()
		local api, mock = newConfiguredAPI()
		mock:SetResponder(function()
			return Promise.rejected("connection refused")
		end)

		api:QueuePoint(newPoint())

		local outcome, payload = PromiseTestUtils.awaitOutcome(api:PromiseFlush())
		expect(outcome).toEqual("rejected")
		expect(payload).toEqual("connection refused")

		api:Destroy()
	end)

	it("should resolve without a request when nothing is buffered", function()
		local api, mock = newConfiguredAPI()

		expect(PromiseTestUtils.awaitSettled(api:PromiseFlush())).toEqual(true)
		expect(#mock:GetRequests()).toEqual(0)

		api:Destroy()
	end)
end)
