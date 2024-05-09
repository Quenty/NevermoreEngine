--[[
	@class ObservableCountingMap.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local ObservableCountingMap = require("ObservableCountingMap")

return function()
	describe("ObservableCountingMap.new()", function()
		local observableCountingMap = ObservableCountingMap.new()

		it("should return 0 for unset values", function()
			expect(observableCountingMap:Get("a")).to.equal(0)
			expect(observableCountingMap:GetTotalKeyCount()).to.equal(0)
		end)

		it("should allow you to add to a value", function()
			expect(observableCountingMap:Get("a")).to.equal(0)
			expect(observableCountingMap:GetTotalKeyCount()).to.equal(0)
			observableCountingMap:Add("a", 5)
			expect(observableCountingMap:Get("a")).to.equal(5)
			expect(observableCountingMap:GetTotalKeyCount()).to.equal(1)
		end)

		it("should allow you to add to a value that is already defined", function()
			expect(observableCountingMap:Get("a")).to.equal(5)
			expect(observableCountingMap:GetTotalKeyCount()).to.equal(1)
			observableCountingMap:Add("a", 5)
			expect(observableCountingMap:Get("a")).to.equal(10)
			expect(observableCountingMap:GetTotalKeyCount()).to.equal(1)
		end)

		it("should clean up", function()
			observableCountingMap:Destroy()
		end)
	end)
end
