--!strict
--[[
	@class PagesDatabase.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PagesDatabase = require("PagesDatabase")
local PagesProxy = require("PagesProxy")
local PagesUtils = require("PagesUtils")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PagesDatabase.fromPageData", function()
	it("should store each page with the last one finished", function()
		local database = PagesDatabase.fromPageData({
			{ "a", "b" },
			{ "c" },
		})

		expect(PagesDatabase.isPagesDatabase(database)).toBe(true)
		expect(database:GetPage(1)).toEqual({ "a", "b" })
		expect(database:GetIsFinished(1)).toBe(false)
		expect(database:GetPage(2)).toEqual({ "c" })
		expect(database:GetIsFinished(2)).toBe(true)
	end)

	it("should mirror an empty engine result as one finished empty page", function()
		local database = PagesDatabase.fromPageData({})

		expect(database:GetPage(1)).toEqual({})
		expect(database:GetIsFinished(1)).toBe(true)
	end)

	it("should no-op advancement to already-stored pages", function()
		local database = PagesDatabase.fromPageData({ { "a" }, { "b" } })

		database:IncrementToPageIdAsync(2)

		expect(database:GetPage(2)).toEqual({ "b" })
	end)

	it("should error on advancement past the stored pages", function()
		local database = PagesDatabase.fromPageData({ { "a" } })

		expect(function()
			database:IncrementToPageIdAsync(2)
		end).toThrow()
	end)
end)

describe("PagesProxy over a static database", function()
	it("should duck-type as a pages instance and iterate every page", function()
		local proxy = PagesProxy.new(PagesDatabase.fromPageData({
			{ "a", "b" },
			{ "c" },
		}))

		expect(PagesProxy.isPagesProxy(proxy)).toBe(true)
		expect(proxy:GetCurrentPage()).toEqual({ "a", "b" })
		expect((proxy :: any).IsFinished).toBe(false)

		proxy:AdvanceToNextPageAsync()

		expect(proxy:GetCurrentPage()).toEqual({ "c" })
		expect((proxy :: any).IsFinished).toBe(true)
		expect(function()
			proxy:AdvanceToNextPageAsync()
		end).toThrow()
	end)

	it("should clone without sharing advancement state", function()
		local proxy = PagesProxy.new(PagesDatabase.fromPageData({ { "a" }, { "b" } }))
		local clone = proxy:Clone()

		clone:AdvanceToNextPageAsync()

		expect(proxy:GetCurrentPage()).toEqual({ "a" })
		expect(clone:GetCurrentPage()).toEqual({ "b" })
	end)
end)

describe("PagesUtils.promiseAdvanceToNextPage", function()
	it("should resolve the next page's content for a proxy", function()
		local proxy = PagesProxy.new(PagesDatabase.fromPageData({ { "a" }, { "b" } }))

		local promise = PagesUtils.promiseAdvanceToNextPage(proxy :: any)
		local outcome, value = PromiseTestUtils.awaitOutcome(promise)

		expect(outcome).toBe("resolved")
		expect(value).toEqual({ "b" })
	end)

	it("should reject when the proxy is already finished", function()
		local proxy = PagesProxy.new(PagesDatabase.fromPageData({ { "a" } }))

		local promise = PagesUtils.promiseAdvanceToNextPage(proxy :: any)
		local outcome = PromiseTestUtils.awaitOutcome(promise)

		expect(outcome).toBe("rejected")
	end)
end)
