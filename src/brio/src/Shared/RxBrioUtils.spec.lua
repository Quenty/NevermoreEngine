--[[
	Unit tests for RxBrioUtils.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local RxBrioUtils = require("RxBrioUtils")
local Brio = require("Brio")
local Observable = require("Observable")

return function()
	describe("RxBrioUtils.combineLatest({})", function()
		it("should execute immediately", function()
			local observe = RxBrioUtils.combineLatest({})
			local brio
			local sub = observe:Subscribe(function(result)
				brio = result
			end)
			expect(brio).to.be.ok()
			expect(Brio.isBrio(brio)).to.equal(true)
			expect(brio:IsDead()).to.equal(true)

			sub:Destroy()
		end)
	end)

	describe("RxBrioUtils.combineLatest({ value = Observable(Brio(5)) })", function()
		it("should execute immediately", function()
			local observe = RxBrioUtils.combineLatest({
				value = Observable.new(function(sub)
					sub:Fire(Brio.new(5));
				end);
				otherValue = 25;
			})
			local brio

			local sub = observe:Subscribe(function(result)
				brio = result
			end)
			expect(brio).to.be.ok()
			expect(Brio.isBrio(brio)).to.equal(true)
			expect(not brio:IsDead()).to.equal(true)
			expect(brio:GetValue()).to.be.a("table")
			expect(brio:GetValue().value).to.equal(5)

			sub:Destroy()
		end)
	end)

	describe("RxBrioUtils.flatCombineLatest", function()
		local doFire
		local brio = Brio.new(5)
		local observe = RxBrioUtils.flatCombineLatest({
			value = Observable.new(function(sub)
				sub:Fire(brio);
				doFire = function(...)
					sub:Fire(...)
				end
			end);
			otherValue = 25;
		})

		local lastResult = nil
		local fireCount = 0

		local sub = observe:Subscribe(function(result)
			lastResult = result
			fireCount = fireCount + 1
		end)

		it("should execute immediately", function()
			expect(fireCount).to.equal(1)
			expect(lastResult).to.be.a("table")
			expect(Brio.isBrio(lastResult)).to.equal(false)
			expect(lastResult.value).to.equal(5)
			expect(lastResult.otherValue).to.equal(25)
		end)

		it("should reset when the brio is killed", function()
			expect(fireCount).to.equal(1)

			brio:Kill()

			expect(fireCount).to.equal(2)
			expect(lastResult).to.be.a("table")
			expect(Brio.isBrio(lastResult)).to.equal(false)
			expect(lastResult.value).to.equal(nil)
			expect(lastResult.otherValue).to.equal(25)
		end)

		it("should allow a new value", function()
			expect(fireCount).to.equal(2)

			doFire(Brio.new(70))

			expect(fireCount).to.equal(3)
			expect(lastResult).to.be.a("table")
			expect(Brio.isBrio(lastResult)).to.equal(false)
			expect(lastResult.value).to.equal(70)
			expect(lastResult.otherValue).to.equal(25)
		end)

		it("should only fire once if we replace the value", function()
			expect(fireCount).to.equal(3)

			doFire(Brio.new(75))

			expect(fireCount).to.equal(4)
			expect(lastResult).to.be.a("table")
			expect(Brio.isBrio(lastResult)).to.equal(false)
			expect(lastResult.value).to.equal(75)
			expect(lastResult.otherValue).to.equal(25)
		end)

		it("should cleanup the sub", function()
			sub:Destroy()
		end)
	end)
end
