--!strict
--[[
	@class SortedNodeValue.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local SortFunctionUtils = require("SortFunctionUtils")
local SortedNodeValue = require("SortedNodeValue")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function defaultCompare(a: number, b: number): number
	return SortFunctionUtils.default(a, b)
end

describe("SortedNodeValue", function()
	describe("new", function()
		it("should construct with a value and compare function", function()
			local nodeValue = SortedNodeValue.new(5, defaultCompare)
			expect(nodeValue).never.toEqual(nil)
		end)
	end)

	describe("GetValue", function()
		it("should return the stored value", function()
			local nodeValue = SortedNodeValue.new(42, defaultCompare)
			expect(nodeValue:GetValue()).toEqual(42)
		end)
	end)

	describe("isSortedNodeValue", function()
		it("should return true for a SortedNodeValue", function()
			local nodeValue = SortedNodeValue.new(1, defaultCompare)
			expect(SortedNodeValue.isSortedNodeValue(nodeValue)).toEqual(true)
		end)

		it("should return false for other values", function()
			expect(SortedNodeValue.isSortedNodeValue({})).toEqual(false)
			expect(SortedNodeValue.isSortedNodeValue(nil)).toEqual(false)
			expect(SortedNodeValue.isSortedNodeValue(5)).toEqual(false)
			expect(SortedNodeValue.isSortedNodeValue("hello")).toEqual(false)
		end)
	end)

	describe("__eq", function()
		it("should return true for equal values", function()
			local a = SortedNodeValue.new(5, defaultCompare)
			local b = SortedNodeValue.new(5, defaultCompare)
			expect(a == b).toEqual(true)
		end)

		it("should return false for different values", function()
			local a = SortedNodeValue.new(3, defaultCompare)
			local b = SortedNodeValue.new(7, defaultCompare)
			expect(a == b).toEqual(false)
		end)
	end)

	describe("__lt", function()
		it("should return true when a < b", function()
			local a = SortedNodeValue.new(1, defaultCompare)
			local b = SortedNodeValue.new(2, defaultCompare)
			expect(a < b).toEqual(true)
		end)

		it("should return false when a >= b", function()
			local a = SortedNodeValue.new(5, defaultCompare)
			local b = SortedNodeValue.new(3, defaultCompare)
			expect(a < b).toEqual(false)

			local c = SortedNodeValue.new(5, defaultCompare)
			expect(a < c).toEqual(false)
		end)
	end)

	describe("__gt", function()
		it("should return true when a > b", function()
			local a = SortedNodeValue.new(10, defaultCompare)
			local b = SortedNodeValue.new(2, defaultCompare)
			expect(a > b).toEqual(true)
		end)

		it("should return false when a <= b", function()
			local a = SortedNodeValue.new(1, defaultCompare)
			local b = SortedNodeValue.new(5, defaultCompare)
			expect(a > b).toEqual(false)

			local c = SortedNodeValue.new(1, defaultCompare)
			expect(a > c).toEqual(false)
		end)
	end)

	describe("custom compare", function()
		it("should use the provided compare function for ordering", function()
			-- Reverse compare: higher values sort first
			local reverseCompare = function(a: number, b: number): number
				return b - a
			end

			local a = SortedNodeValue.new(1, reverseCompare)
			local b = SortedNodeValue.new(2, reverseCompare)

			-- With reverse compare, 1 > 2 in sort order
			expect(a > b).toEqual(true)
			expect(a < b).toEqual(false)
		end)
	end)
end)
