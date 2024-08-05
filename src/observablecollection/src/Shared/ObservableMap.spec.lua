--[[
	@class ObservableMap.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local ObservableMap = require("ObservableMap")

return function()
	describe("ObservableMap.new()", function()
		local observableMap = ObservableMap.new()

		it("should return nil for unset values", function()
			expect(observableMap:Get("a")).to.equal(nil)
		end)

		it("should allow setting a value", function()
			expect(observableMap:GetCount()).to.equal(0)

			observableMap:Set("a", "Hello World")

			expect(observableMap:Get("a")).to.equal("Hello World")
			expect(observableMap:GetCount()).to.equal(1)
		end)

		it("should overwrite values", function()
			expect(observableMap:Get("a")).to.equal("Hello World")

			observableMap:Set("a", "Hello World 2")

			expect(observableMap:Get("a")).to.equal("Hello World 2")
		end)

		it("should allow false as a key", function()
			expect(observableMap:Get(false)).to.equal(nil)
			observableMap:Set(false, "Hello")
			expect(observableMap:Get(false)).to.equal("Hello")
		end)

		it("should fire off events for a specific key", function()
			local seen = {}
			local sub = observableMap:ObserveValueForKey("c"):Subscribe(function(value)
				table.insert(seen, value)
			end)
			observableMap:Set("c", "Hello")

			sub:Destroy()

			expect(#seen).to.equal(1)
			expect(seen[1]).to.equal("Hello")
		end)

		it("should fire off events for all keys", function()
			local seen = {}
			local sub = observableMap:ObserveValuesBrio():Subscribe(function(value)
				table.insert(seen, value)
			end)
			observableMap:Set("d", "Hello")

			expect(#seen).to.equal(4)
			expect(seen[4]:GetValue()).to.equal("Hello")
			expect(seen[4]:IsDead()).to.equal(false)

			sub:Destroy()

			expect(#seen).to.equal(4)
			expect(seen[4]:IsDead()).to.equal(true)
		end)

		it("should clean up", function()
			observableMap:Destroy()
		end)
	end)
end
