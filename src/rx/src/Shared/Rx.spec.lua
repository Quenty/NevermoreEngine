--[[
	@class Rx.spec.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local Rx = require("Rx")

return function()
	describe("Rx.combineLatest({})", function()
		local observe = Rx.combineLatest({})
		local externalResult

		it("should execute immediately", function()
			local sub = observe:Subscribe(function(result)
				externalResult = result
			end)

			expect(externalResult).to.be.a("table")
			sub:Destroy()
		end)
	end)

	describe("Rx.combineLatest({ value = 5 })", function()
		local observe = Rx.combineLatest({ value = 5 })
		local externalResult

		it("should execute immediately", function()
			local sub = observe:Subscribe(function(result)
				externalResult = result
			end)

			expect(externalResult).to.be.a("table")
			expect(externalResult.value).to.equal(5)
			sub:Destroy()
		end)
	end)

	describe("Rx.combineLatest({ value = Rx.of(5) })", function()
		local observe = Rx.combineLatest({ value = Rx.of(5) })
		local externalResult

		it("should execute immediately", function()
			local sub = observe:Subscribe(function(result)
				externalResult = result
			end)

			expect(externalResult).to.be.a("table")
			expect(externalResult.value).to.equal(5)
			sub:Destroy()
		end)
	end)
end
