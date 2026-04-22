--!strict
--[[
	@class SortFunctionUtils.spec.lua
]]

local require = (require :: any)(
		game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent
	).bootstrapStory(script) :: typeof(require(script.Parent.loader).load(script))

local Jest = require("Jest")
local SortFunctionUtils = require("SortFunctionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("SortFunctionUtils", function()
	describe("default", function()
		it("should return negative when a < b", function()
			expect(SortFunctionUtils.default(1, 2)).toEqual(-1)
		end)

		it("should return positive when a > b", function()
			expect(SortFunctionUtils.default(2, 1)).toEqual(1)
		end)

		it("should return zero when a == b", function()
			expect(SortFunctionUtils.default(5, 5)).toEqual(0)
		end)

		it("should compare strings", function()
			expect(SortFunctionUtils.default("a", "b")).toEqual(-1)
			expect(SortFunctionUtils.default("b", "a")).toEqual(1)
			expect(SortFunctionUtils.default("a", "a")).toEqual(0)
		end)
	end)

	describe("reverse", function()
		it("should reverse the default sort", function()
			local reversed = SortFunctionUtils.reverse(nil)

			expect(reversed(1, 2)).toEqual(1)
			expect(reversed(2, 1)).toEqual(-1)
			expect(reversed(5, 5)).toEqual(0)
		end)

		it("should reverse a custom compare function", function()
			local custom = function(a: number, b: number): number
				return a - b
			end
			local reversed = SortFunctionUtils.reverse(custom)

			expect(reversed(1, 2)).toEqual(1)
			expect(reversed(2, 1)).toEqual(-1)
			expect(reversed(3, 3)).toEqual(0)
		end)
	end)

	describe("emptyIterator", function()
		it("should return nothing", function()
			local count = 0
			for _ in SortFunctionUtils.emptyIterator do
				count += 1
			end
			expect(count).toEqual(0)
		end)
	end)
end)
