--[[
	Unit tests for BrioUtils.lua
]]

local require =
	require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local Brio = require("Brio")
local BrioUtils = require("BrioUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("BrioUtils.flatten({})", function()
	local brio = BrioUtils.flatten({})

	describe("should return a brio that", function()
		it("is a brio", function()
			expect(brio).toEqual(expect.any("table"))
			expect(Brio.isBrio(brio)).toEqual(true)
		end)

		it("is alive", function()
			expect(not brio:IsDead()).toEqual(true)
		end)

		it("contains a table", function()
			expect(brio:GetValue()).toEqual(expect.any("table"))
		end)

		it("contains a table with nothing in it", function()
			expect(next(brio:GetValue())).toEqual(nil)
		end)
	end)
end)

describe("BrioUtils.flatten with out a brio in it", function()
	local brio = BrioUtils.flatten({
		value = 5,
	})

	describe("should return a brio that", function()
		it("is a brio", function()
			expect(brio).toEqual(expect.any("table"))
			expect(Brio.isBrio(brio)).toEqual(true)
		end)

		it("is alive", function()
			expect(not brio:IsDead()).toEqual(true)
		end)

		it("contains a table", function()
			expect(brio:GetValue()).toEqual(expect.any("table"))
		end)

		it("contains a table with value", function()
			expect(brio:GetValue().value).toEqual(5)
		end)
	end)
end)

describe("BrioUtils.flatten a dead brio in it", function()
	local brio = BrioUtils.flatten({
		value = Brio.DEAD,
	})

	describe("should return a brio that", function()
		it("is a brio", function()
			expect(brio).toEqual(expect.any("table"))
			expect(Brio.isBrio(brio)).toEqual(true)
		end)

		it("is dead", function()
			expect(brio:IsDead()).toEqual(true)
		end)
	end)
end)
