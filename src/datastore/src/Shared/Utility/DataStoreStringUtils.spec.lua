--!strict
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

	it("should return true across the full 7-bit ASCII range", function()
		local bytes = {}
		for i = 0, 127 do
			bytes[i + 1] = string.char(i)
		end
		local result = DataStoreStringUtils.isValidUTF8(table.concat(bytes))
		expect(result).toEqual(true)
	end)

	it("should return true for control characters and embedded NUL bytes", function()
		expect(DataStoreStringUtils.isValidUTF8("line\r\n\tvalue")).toEqual(true)
		expect(DataStoreStringUtils.isValidUTF8("with\0null")).toEqual(true)
	end)

	it("should return true at the 127 boundary and false at 128", function()
		expect(DataStoreStringUtils.isValidUTF8(string.char(127))).toEqual(true)

		local result, reason = DataStoreStringUtils.isValidUTF8(string.char(128))
		expect(result).toEqual(false)
		expect(reason).toEqual("Invalid string")
	end)

	it("should reject well-formed UTF-8 that contains non-ASCII code points", function()
		-- "café" is valid UTF-8 but the accented character is above the ASCII range, which is the
		-- string-saving-attack surface isValidUTF8 exists to block.
		local result, reason = DataStoreStringUtils.isValidUTF8("caf\u{00E9}")
		expect(result).toEqual(false)
		expect(reason).toEqual("Invalid string")
	end)

	it("should reject emoji and other multi-byte code points", function()
		local result, reason = DataStoreStringUtils.isValidUTF8("party \u{1F389}")
		expect(result).toEqual(false)
		expect(reason).toEqual("Invalid string")
	end)

	it("should reject bytes that are not valid UTF-8 at all", function()
		-- 0xFF is never a legal UTF-8 byte, so utf8.len fails before the ASCII check runs.
		local result, reason = DataStoreStringUtils.isValidUTF8(string.char(255))
		expect(result).toEqual(false)
		expect(reason).toEqual("Invalid string")
	end)

	it("should reject a lone continuation byte", function()
		local result, reason = DataStoreStringUtils.isValidUTF8(string.char(0x80))
		expect(result).toEqual(false)
		expect(reason).toEqual("Invalid string")
	end)

	it("should return false with a reason for nil and table values", function()
		local nilResult, nilReason = DataStoreStringUtils.isValidUTF8(nil :: any)
		expect(nilResult).toEqual(false)
		expect(nilReason).toEqual("Not a string")

		local tableResult, tableReason = DataStoreStringUtils.isValidUTF8({} :: any)
		expect(tableResult).toEqual(false)
		expect(tableReason).toEqual("Not a string")
	end)
end)
