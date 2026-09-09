--!strict
--[[
	@class BindableEncodingUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BindableEncodingUtils = require("BindableEncodingUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("BindableEncodingUtils.encode(value)", function()
	it("should pass through numbers", function()
		expect(BindableEncodingUtils.encode(5)).toEqual(5)
	end)

	it("should pass through strings", function()
		expect(BindableEncodingUtils.encode("hello")).toEqual("hello")
	end)

	it("should wrap tables in a function", function()
		local encoded = BindableEncodingUtils.encode({ a = 1 })
		expect(type(encoded)).toEqual("function")
	end)
end)

describe("BindableEncodingUtils.decode(value)", function()
	it("should pass through numbers", function()
		expect(BindableEncodingUtils.decode(5)).toEqual(5)
	end)

	it("should unwrap functions", function()
		local value = { a = 1 }
		local encoded = BindableEncodingUtils.encode(value)
		local decoded = BindableEncodingUtils.decode(encoded)
		expect(decoded).toEqual(value)
	end)
end)
