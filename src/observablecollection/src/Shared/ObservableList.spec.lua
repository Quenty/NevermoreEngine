--[[
	@class ObservableList.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local ObservableList = require("ObservableList")

return function()
	describe("ObservableList.new()", function()
		local observableList = ObservableList.new()

		it("should return nil for unset values", function()
			expect(observableList:Get(1)).to.equal(nil)
		end)

		it("should allow inserting an value", function()
			expect(observableList:GetCount()).to.equal(0)

			observableList:Add("a")

			expect(observableList:Get(1)).to.equal("a")
			expect(observableList:GetCount()).to.equal(1)
		end)

		it("should allow negative queries", function()
			expect(observableList:Get(-1)).to.equal("a")
			expect(observableList:Get(-2)).to.equal(nil)
		end)

		it("should allow false as a value", function()
			expect(observableList:Get(2)).to.equal(nil)
			observableList:Add(false)
			expect(observableList:Get(2)).to.equal(false)
		end)

		it("should allow negative queries after false", function()
			expect(observableList:Get(1)).to.equal("a")
			expect(observableList:Get(2)).to.equal(false)

			expect(observableList:Get(-1)).to.equal(false)
			expect(observableList:Get(-2)).to.equal("a")
		end)

		it("should fire off events for a specific key", function()
			local seen = {}
			local sub = observableList:ObserveIndex(1):Subscribe(function(value)
				table.insert(seen, value)
			end)
			observableList:InsertAt("c", 1)

			sub:Destroy()

			expect(#seen).to.equal(2)
			expect(seen[1]).to.equal(1)
			expect(seen[2]).to.equal(2)
		end)

		it("should fire off events for all keys", function()
			local seen = {}
			local sub = observableList:ObserveItemsBrio():Subscribe(function(value)
				table.insert(seen, value)
			end)
			observableList:Add("a")

			expect(#seen).to.equal(4)
			expect(seen[4]:GetValue()).to.equal("a")
			expect(seen[4]:IsDead()).to.equal(false)

			sub:Destroy()

			expect(#seen).to.equal(4)
			expect(seen[4]:IsDead()).to.equal(true)
		end)

		it("it should be able to observe a specific key", function()
			local seen = {}
			local sub = observableList:ObserveAtIndex(1):Subscribe(function(value)
				table.insert(seen, value)
			end)

			local originalList = observableList:GetList()
			expect(originalList[1]).to.equal("c")

			observableList:InsertAt("dragon", 1)

			sub:Destroy()

			expect(#seen).to.equal(2)
			expect(seen[1]).to.equal("c")
			expect(seen[2]).to.equal("dragon")
		end)

		it("it should be able to observe a specific negative key", function()
			local seen = {}
			local sub = observableList:ObserveAtIndex(-1):Subscribe(function(value)
				table.insert(seen, value)
			end)

			local originalList = observableList:GetList()
			expect(originalList[#originalList]).to.equal("a")

			observableList:Add("fire")

			sub:Destroy()

			expect(#seen).to.equal(2)
			expect(seen[1]).to.equal("a")
			expect(seen[2]).to.equal("fire")
		end)

		it("should fire off events on removal", function()
			local seen = {}
			local sub = observableList:ObserveIndex(2):Subscribe(function(value)
				table.insert(seen, value)
			end)
			observableList:RemoveAt(1)

			sub:Destroy()

			expect(#seen).to.equal(2)
			expect(seen[1]).to.equal(2)
			expect(seen[2]).to.equal(1)
		end)

		it("should clean up", function()
			observableList:Destroy()
		end)
	end)
end
