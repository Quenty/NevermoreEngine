--[[
	Unit tests for BrioUtils.lua
]]

local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local BrioUtils = require("BrioUtils")
local Brio = require("Brio")

return function()
	describe("BrioUtils.flatten({})", function()
		local brio = BrioUtils.flatten({})

		describe("should return a brio that", function()
			it("is a brio", function()
				expect(brio).to.be.a("table")
				expect(Brio.isBrio(brio)).to.equal(true)
			end)

			it("is alive", function()
				expect(not brio:IsDead()).to.equal(true)
			end)

			it("contains a table", function()
				expect(brio:GetValue()).to.be.a("table")
			end)

			it("contains a table with nothing in it", function()
				expect(next(brio:GetValue())).to.equal(nil)
			end)
		end)
	end)

	describe("BrioUtils.flatten with out a brio in it", function()
		local brio = BrioUtils.flatten({
			value = 5;
		})

		describe("should return a brio that", function()
			it("is a brio", function()
				expect(brio).to.be.a("table")
				expect(Brio.isBrio(brio)).to.equal(true)
			end)

			it("is alive", function()
				expect(not brio:IsDead()).to.equal(true)
			end)

			it("contains a table", function()
				expect(brio:GetValue()).to.be.a("table")
			end)

			it("contains a table with value", function()
				expect(brio:GetValue().value).to.equal(5)
			end)
		end)
	end)

	describe("BrioUtils.flatten a dead brio in it", function()
		local brio = BrioUtils.flatten({
			value = Brio.DEAD;
		})

		describe("should return a brio that", function()
			it("is a brio", function()
				expect(brio).to.be.a("table")
				expect(Brio.isBrio(brio)).to.equal(true)
			end)

			it("is dead", function()
				expect(brio:IsDead()).to.equal(true)
			end)
		end)
	end)
end
