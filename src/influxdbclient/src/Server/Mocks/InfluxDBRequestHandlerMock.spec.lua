--!strict
--[[
	@class InfluxDBRequestHandlerMock.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBRequestHandlerMock = require("InfluxDBRequestHandlerMock")
local Jest = require("Jest")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function request(url: string): any
	return {
		Method = "POST",
		Url = url,
		Headers = {},
		Body = "",
	}
end

describe("InfluxDBRequestHandlerMock.isInfluxDBRequestHandlerMock", function()
	it("should be true for a mock", function()
		expect(InfluxDBRequestHandlerMock.isInfluxDBRequestHandlerMock(InfluxDBRequestHandlerMock.new())).toEqual(true)
	end)

	it("should be false for other values", function()
		expect(InfluxDBRequestHandlerMock.isInfluxDBRequestHandlerMock(nil)).toEqual(false)
		expect(InfluxDBRequestHandlerMock.isInfluxDBRequestHandlerMock({})).toEqual(false)
		expect(InfluxDBRequestHandlerMock.isInfluxDBRequestHandlerMock(5)).toEqual(false)
	end)
end)

describe("InfluxDBRequestHandlerMock.Handler", function()
	it("should record each request in order", function()
		local mock = InfluxDBRequestHandlerMock.new()

		mock.Handler(request("https://a.example.com"))
		mock.Handler(request("https://b.example.com"))

		local requests = mock:GetRequests()
		expect(#requests).toEqual(2)
		expect(requests[1].Url).toEqual("https://a.example.com")
		expect(requests[2].Url).toEqual("https://b.example.com")
	end)

	it("should resolve with a default success response", function()
		local mock = InfluxDBRequestHandlerMock.new()

		local outcome, payload = PromiseTestUtils.awaitOutcome(mock.Handler(request("https://a.example.com")))
		expect(outcome).toEqual("resolved")
		expect(payload.Success).toEqual(true)
		expect(payload.StatusCode).toEqual(204)
	end)
end)

describe("InfluxDBRequestHandlerMock.GetLastRequest", function()
	it("should return nil before any request", function()
		local mock = InfluxDBRequestHandlerMock.new()
		expect(mock:GetLastRequest()).toEqual(nil)
	end)

	it("should return the most recent request", function()
		local mock = InfluxDBRequestHandlerMock.new()
		mock.Handler(request("https://a.example.com"))
		mock.Handler(request("https://b.example.com"))

		expect((mock:GetLastRequest() :: any).Url).toEqual("https://b.example.com")
	end)
end)

describe("InfluxDBRequestHandlerMock.SetResponder", function()
	it("should route requests through a custom responder", function()
		local mock = InfluxDBRequestHandlerMock.new()
		mock:SetResponder(function()
			return Promise.rejected("boom")
		end)

		local outcome, payload = PromiseTestUtils.awaitOutcome(mock.Handler(request("https://a.example.com")))
		expect(outcome).toEqual("rejected")
		expect(payload).toEqual("boom")
		-- The request is still recorded even when the responder rejects.
		expect(#mock:GetRequests()).toEqual(1)
	end)

	it("should restore the default response when set back to nil", function()
		local mock = InfluxDBRequestHandlerMock.new()
		mock:SetResponder(function()
			return Promise.rejected("boom")
		end)
		mock:SetResponder(nil)

		local outcome = PromiseTestUtils.awaitOutcome(mock.Handler(request("https://a.example.com")))
		expect(outcome).toEqual("resolved")
	end)

	it("should throw on a non-function, non-nil responder", function()
		local mock = InfluxDBRequestHandlerMock.new()
		expect(function()
			mock:SetResponder(5 :: any)
		end).toThrow("Bad responder")
	end)
end)
