--!strict
--[[
	@class PlayerMockConstants.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local PlayerMockConstants = require("PlayerMockConstants")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("PlayerMockConstants", function()
	it("is frozen, so no consumer can retag every mock in the place at once", function()
		local constants = PlayerMockConstants :: any

		expect(function()
			constants.MOCK_TAG = "SomethingElse"
		end).toThrow()
	end)

	it("names every constant with a non-empty string", function()
		for name, value in PlayerMockConstants :: any do
			expect(typeof(name)).toBe("string")
			expect(typeof(value)).toBe("string")
			expect(#value > 0).toBe(true)
		end
	end)

	it("gives every constant a distinct value, so two names cannot collide in the DataModel", function()
		local nameByValue: { [string]: string } = {}

		for name, value in PlayerMockConstants :: any do
			expect(nameByValue[value]).toBeNil()
			nameByValue[value] = name
		end
	end)
end)
