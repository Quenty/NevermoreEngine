--[[
	@class ObservableMapList.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local ObservableMapList = require("ObservableMapList")

return function()
	describe("ObservableMapList.new()", function()
		local observableMapList = ObservableMapList.new()

		it("should return nil for unset values", function()
			expect(observableMapList:GetAtListIndex("dragon", 1)).to.equal(nil)
		end)

		it("should allow additions", function()
			observableMapList:Add("hello", "dragon")
			expect(observableMapList:GetAtListIndex("dragon", 1)).to.equal("hello")
			expect(observableMapList:GetAtListIndex("dragon", -1)).to.equal("hello")
			expect(observableMapList:GetAtListIndex("fire", 1)).to.equal(nil)
		end)
	end)
end
