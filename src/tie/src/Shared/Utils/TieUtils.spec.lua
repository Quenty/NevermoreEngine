--!nonstrict
--[[
	@class TieUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local TieUtils = require("TieUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("TieUtils.encode(value)", function()
	it("should pass through numbers", function()
		expect(TieUtils.encode(5)).toEqual(5)
	end)

	it("should pass through strings", function()
		expect(TieUtils.encode("hello")).toEqual("hello")
	end)

	it("should wrap tables in a function", function()
		local encoded = TieUtils.encode({ a = 1 })
		expect(type(encoded)).toEqual("function")
	end)
end)

describe("TieUtils.decode(value)", function()
	it("should pass through numbers", function()
		expect(TieUtils.decode(5)).toEqual(5)
	end)

	it("should unwrap functions", function()
		local value = { a = 1 }
		local encoded = TieUtils.encode(value)
		local decoded = TieUtils.decode(encoded)
		expect(decoded).toEqual(value)
	end)
end)
