--!strict
--[[
	@class InfluxDBEscapeUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InfluxDBEscapeUtils = require("InfluxDBEscapeUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("InfluxDBEscapeUtils.measurement", function()
	it("should pass through fine", function()
		local measurement = InfluxDBEscapeUtils.measurement("hi")
		expect(measurement).toBe("hi")
	end)

	it("should escape tabs", function()
		local measurement = InfluxDBEscapeUtils.measurement("\thi")
		expect(measurement).toBe("\\thi")
	end)
end)

describe("InfluxDBEscapeUtils.quoted", function()
	it("should pass through fine", function()
		expect(InfluxDBEscapeUtils.quoted("hi")).toBe('"hi"')
	end)

	it("should escape quotes", function()
		expect(InfluxDBEscapeUtils.quoted('"hi')).toBe('"\\"hi"')
	end)
end)

describe("InfluxDBEscapeUtils.measurement", function()
	it("should escape commas", function()
		expect(InfluxDBEscapeUtils.measurement("a,b")).toBe("a\\,b")
	end)

	it("should escape spaces", function()
		expect(InfluxDBEscapeUtils.measurement("a b")).toBe("a\\ b")
	end)

	it("should not escape equals signs", function()
		expect(InfluxDBEscapeUtils.measurement("a=b")).toBe("a=b")
	end)
end)

describe("InfluxDBEscapeUtils.quoted", function()
	it("should escape backslashes", function()
		expect(InfluxDBEscapeUtils.quoted("a\\b")).toBe('"a\\\\b"')
	end)

	it("should wrap an empty string in quotes", function()
		expect(InfluxDBEscapeUtils.quoted("")).toBe('""')
	end)
end)

describe("InfluxDBEscapeUtils.tag", function()
	it("should pass through fine", function()
		local tag = InfluxDBEscapeUtils.tag("hi")
		expect(tag).toBe("hi")
	end)

	it("should escape tabs", function()
		local tag = InfluxDBEscapeUtils.tag("\thi")
		expect(tag).toBe("\\thi")
	end)

	it("should escape =", function()
		local tag = InfluxDBEscapeUtils.tag("=hi")
		expect(tag).toBe("\\=hi")
	end)

	it("should escape = and \\", function()
		local tag = InfluxDBEscapeUtils.tag("\\=hi")
		expect(tag).toBe("\\\\\\=hi")
	end)

	it("should escape \\n", function()
		local tag = InfluxDBEscapeUtils.tag("\nhi")
		expect(tag).toBe("\\nhi")
	end)

	it("should escape commas and spaces", function()
		expect(InfluxDBEscapeUtils.tag("a, b")).toBe("a\\,\\ b")
	end)
end)

describe("InfluxDBEscapeUtils.createEscaper", function()
	it("should replace only the characters in the sub table", function()
		local escaper = InfluxDBEscapeUtils.createEscaper({
			["#"] = "\\#",
		})

		expect(escaper("a#b#c")).toBe("a\\#b\\#c")
		expect(escaper("abc")).toBe("abc")
	end)

	it("should escape Lua pattern magic characters used as keys", function()
		local escaper = InfluxDBEscapeUtils.createEscaper({
			["."] = "\\.",
			["%"] = "\\%",
		})

		expect(escaper("a.b%c")).toBe("a\\.b\\%c")
	end)

	it("should throw on a non-table sub table", function()
		expect(function()
			InfluxDBEscapeUtils.createEscaper(5 :: any)
		end).toThrow("Bad subTable")
	end)

	it("should throw on a multi-character key", function()
		expect(function()
			InfluxDBEscapeUtils.createEscaper({ ab = "x" })
		end).toThrow("Bad char")
	end)
end)

describe("InfluxDBEscapeUtils.createQuotedEscaper", function()
	it("should wrap the escaped result in quotes", function()
		local escaper = InfluxDBEscapeUtils.createQuotedEscaper({
			["#"] = "\\#",
		})

		expect(escaper("a#b")).toBe('"a\\#b"')
	end)
end)
