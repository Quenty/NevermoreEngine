--[[
	@class ObservableSortedList.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local ObservableSortedList = require("ObservableSortedList")
local Rx = require("Rx")
local StepUtils = require("StepUtils")

return function()
	describe("ObservableSortedList.new()", function()
		local observableSortedList = ObservableSortedList.new()

		it("should return nil for unset values", function()
			expect(observableSortedList:Get(1)).to.equal(nil)
		end)

		it("should allow inserting an value", function()
			expect(observableSortedList:GetCount()).to.equal(0)

			observableSortedList:Add("b", Rx.of("b"))

			StepUtils.deferWait()

			expect(observableSortedList:Get(1)).to.equal("b")
			expect(observableSortedList:GetCount()).to.equal(1)
		end)

		it("should sort the items", function()
			expect(observableSortedList:GetCount()).to.equal(1)

			observableSortedList:Add("a", Rx.of("a"))

			StepUtils.deferWait()

			expect(observableSortedList:Get(1)).to.equal("a")
			expect(observableSortedList:Get(2)).to.equal("b")
			expect(observableSortedList:GetCount()).to.equal(2)
		end)

		it("should add in order if number is the same", function()
			observableSortedList = ObservableSortedList.new()
			observableSortedList:Add("a", Rx.of(0))
			observableSortedList:Add("b", Rx.of(0))
			observableSortedList:Add("c", Rx.of(0))

			StepUtils.deferWait()

			expect(observableSortedList:Get(1)).to.equal("a")
			expect(observableSortedList:Get(2)).to.equal("b")
			expect(observableSortedList:Get(3)).to.equal("c")
			expect(observableSortedList:GetCount()).to.equal(3)
		end)
	end)
end
