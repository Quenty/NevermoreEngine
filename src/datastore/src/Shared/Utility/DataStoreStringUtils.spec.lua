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

	it("should return true at the 127 boundary and false for a lone byte at 128", function()
		expect(DataStoreStringUtils.isValidUTF8(string.char(127))).toEqual(true)

		local result, reason = DataStoreStringUtils.isValidUTF8(string.char(128))
		expect(result).toEqual(false)
		expect(reason).toEqual("Invalid string")
	end)

	it("should return true for well-formed UTF-8 outside ASCII", function()
		local result, reason = DataStoreStringUtils.isValidUTF8("caf\u{00E9}")
		expect(result).toEqual(true)
		expect(reason).toEqual(nil)

		expect(DataStoreStringUtils.isValidUTF8("Eggberg\u{00E9} Egg")).toEqual(true)
		expect(DataStoreStringUtils.isValidUTF8("\u{30B9}\u{30ED}\u{30C3}\u{30C8}")).toEqual(true)
	end)

	it("should return true for emoji and other 4-byte code points", function()
		expect(DataStoreStringUtils.isValidUTF8("party \u{1F389}")).toEqual(true)
	end)

	it("should reject a UTF-16 surrogate encoded as UTF-8", function()
		-- The gist's own example, U+DF8C, plus both ends of the surrogate range.
		for _, surrogate in { "\237\190\140", "\237\160\128", "\237\191\191" } do
			local result, reason = DataStoreStringUtils.isValidUTF8("slot" .. surrogate)
			expect(result).toEqual(false)
			expect(reason).toEqual("Invalid string")
		end
	end)

	it("should reject a surrogate in the middle of otherwise valid text", function()
		expect((DataStoreStringUtils.isValidUTF8("caf\u{00E9}\237\190\140\u{1F389}"))).toEqual(false)
	end)

	it("should reject a surrogate pair encoded as two 3-byte sequences (CESU-8)", function()
		-- U+1F389 as D83C DF89 rather than its single 4-byte form.
		expect((DataStoreStringUtils.isValidUTF8("\237\160\188\237\190\137"))).toEqual(false)
	end)

	it("should return true for code points just outside the surrogate range", function()
		expect(DataStoreStringUtils.isValidUTF8("\u{D7FF}")).toEqual(true)
		expect(DataStoreStringUtils.isValidUTF8("\u{E000}")).toEqual(true)
	end)

	it("should return true for noncharacters, private use, BOM, and U+10FFFF", function()
		-- Data stores save and round-trip all of these unchanged.
		for _, str in { "\u{FFFE}", "\u{FFFF}", "\u{FDD0}", "\u{F8FF}", "\u{FEFF}", "\u{10FFFF}" } do
			expect(DataStoreStringUtils.isValidUTF8(str)).toEqual(true)
		end
	end)

	it("should reject overlong encodings of every length", function()
		expect((DataStoreStringUtils.isValidUTF8("\192\175"))).toEqual(false)
		expect((DataStoreStringUtils.isValidUTF8("\224\128\175"))).toEqual(false)
		expect((DataStoreStringUtils.isValidUTF8("\240\128\128\175"))).toEqual(false)
	end)

	it("should reject code points past U+10FFFF and obsolete 5-byte forms", function()
		expect((DataStoreStringUtils.isValidUTF8("\244\144\128\128"))).toEqual(false)
		expect((DataStoreStringUtils.isValidUTF8("\245\128\128\128"))).toEqual(false)
		expect((DataStoreStringUtils.isValidUTF8("\248\136\128\128\128"))).toEqual(false)
	end)

	it("should reject a truncated multi-byte sequence", function()
		local result = DataStoreStringUtils.isValidUTF8("caf\195")
		expect(result).toEqual(false)
	end)

	it("should reject bytes that are not valid UTF-8 at all", function()
		-- 0xFF is never a legal UTF-8 byte.
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
