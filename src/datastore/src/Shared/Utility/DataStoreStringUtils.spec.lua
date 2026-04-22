--!nonstrict
--[[
	@class DataStoreStringUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local DataStoreStringUtils = require("DataStoreStringUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("DataStoreStringUtils.isValidUTF8(str)", function()
	it("should return true for a valid ASCII string", function()
		local result, reason = DataStoreStringUtils.isValidUTF8("hello")
		expect(result).toEqual(true)
		expect(reason).toEqual(nil)
	end)

	it("should return false for a non-string value", function()
		local result, reason = DataStoreStringUtils.isValidUTF8(5 :: any)
		expect(result).toEqual(false)
		expect(reason).toEqual("Not a string")
	end)

	it("should return true for an empty string", function()
		local result = DataStoreStringUtils.isValidUTF8("")
		expect(result).toEqual(true)
	end)
end)
