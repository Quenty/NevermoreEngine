--[[
	@class Rx.spec.lua
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Jest = require("Jest")
local Rx = require("Rx")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("Rx.combineLatest({})", function()
	local observe = Rx.combineLatest({})
	local externalResult

	it("should execute immediately", function()
		local sub = observe:Subscribe(function(result)
			externalResult = result
		end)

		expect(externalResult).toEqual(expect.any("table"))
		sub:Destroy()
	end)
end)

describe("Rx.combineLatest({ value = 5 })", function()
	local observe = Rx.combineLatest({ value = 5 })
	local externalResult

	it("should execute immediately", function()
		local sub = observe:Subscribe(function(result)
			externalResult = result
		end)

		expect(externalResult).toEqual(expect.any("table"))
		expect(externalResult.value).toEqual(5)
		sub:Destroy()
	end)
end)

describe("Rx.combineLatest({ value = Rx.of(5) })", function()
	local observe = Rx.combineLatest({ value = Rx.of(5) })
	local externalResult

	it("should execute immediately", function()
		local sub = observe:Subscribe(function(result)
			externalResult = result
		end)

		expect(externalResult).toEqual(expect.any("table"))
		expect(externalResult.value).toEqual(5)
		sub:Destroy()
	end)
end)
