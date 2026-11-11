--!strict
--[[
	@class String.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local String = require("String")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("String.trim", function()
	it("trims leading and trailing whitespace by default", function()
		expect(String.trim("  hello  ")).toEqual("hello")
	end)

	it("trims tabs and newlines", function()
		expect(String.trim("\t\nhello world\n\t")).toEqual("hello world")
	end)

	it("leaves interior whitespace untouched", function()
		expect(String.trim("  a  b  ")).toEqual("a  b")
	end)

	it("returns an empty string for all-whitespace input", function()
		expect(String.trim("   ")).toEqual("")
	end)

	it("is a no-op when there is nothing to trim", function()
		expect(String.trim("hello")).toEqual("hello")
	end)

	it("trims a custom pattern", function()
		expect(String.trim("xxhelloxx", "x")).toEqual("hello")
	end)
end)

describe("String.trimFront", function()
	it("trims only the leading whitespace by default", function()
		expect(String.trimFront("  hello  ")).toEqual("hello  ")
	end)

	it("leaves a string without a leading match untouched", function()
		expect(String.trimFront("hello  ")).toEqual("hello  ")
	end)

	it("trims a custom leading pattern", function()
		expect(String.trimFront("xxhello", "x")).toEqual("hello")
	end)
end)

describe("String.toCamelCase", function()
	it("converts snake_case to UpperCamelCase", function()
		expect(String.toCamelCase("hello_world")).toEqual("HelloWorld")
	end)

	it("converts YELL_CASE to UpperCamelCase", function()
		expect(String.toCamelCase("YELL_CASE")).toEqual("YellCase")
	end)

	it("converts space separated words to UpperCamelCase", function()
		expect(String.toCamelCase("hello world")).toEqual("HelloWorld")
	end)

	it("capitalizes the first letter of a single lowercase word", function()
		expect(String.toCamelCase("hello")).toEqual("Hello")
	end)

	it("strips remaining punctuation", function()
		expect(String.toCamelCase("foo-bar")).toEqual("Foobar")
	end)
end)

describe("String.toLowerCamelCase", function()
	it("converts snake_case to lowerCamelCase", function()
		expect(String.toLowerCamelCase("hello_world")).toEqual("helloWorld")
	end)

	it("converts YELL_CASE to lowerCamelCase", function()
		expect(String.toLowerCamelCase("YELL_CASE")).toEqual("yellCase")
	end)

	it("keeps the first letter lowercase", function()
		expect(String.toLowerCamelCase("hello")).toEqual("hello")
	end)
end)

describe("String.uppercaseFirstLetter", function()
	it("uppercases the first letter", function()
		expect(String.uppercaseFirstLetter("hello")).toEqual("Hello")
	end)

	it("leaves an already-uppercase first letter untouched", function()
		expect(String.uppercaseFirstLetter("Hello")).toEqual("Hello")
	end)

	it("is a no-op when the first character is not a letter", function()
		expect(String.uppercaseFirstLetter("123abc")).toEqual("123abc")
	end)
end)

describe("String.toPrivateCase", function()
	it("prefixes with an underscore and lowercases the first letter", function()
		expect(String.toPrivateCase("MyThing")).toEqual("_myThing")
	end)

	it("preserves the remainder of the string", function()
		expect(String.toPrivateCase("SomeValue")).toEqual("_someValue")
	end)
end)

describe("String.checkNumOfCharacterInString", function()
	it("counts the occurrences of a character", function()
		expect(String.checkNumOfCharacterInString("hello", "l")).toEqual(2)
	end)

	it("returns 0 when the character is absent", function()
		expect(String.checkNumOfCharacterInString("hello", "z")).toEqual(0)
	end)

	it("counts every character in the string", function()
		expect(String.checkNumOfCharacterInString("aaaa", "a")).toEqual(4)
	end)
end)

describe("String.isWhitespace", function()
	it("returns true for a string of only whitespace", function()
		expect(String.isWhitespace("   ")).toEqual(true)
	end)

	it("returns false for a string with non-whitespace", function()
		expect(String.isWhitespace("a b")).toEqual(false)
	end)

	it("returns false for an empty string", function()
		expect(String.isWhitespace("")).toEqual(false)
	end)
end)

describe("String.isEmptyOrWhitespaceOrNil", function()
	it("returns true for nil", function()
		expect(String.isEmptyOrWhitespaceOrNil(nil)).toEqual(true)
	end)

	it("returns true for an empty string", function()
		expect(String.isEmptyOrWhitespaceOrNil("")).toEqual(true)
	end)

	it("returns true for a whitespace-only string", function()
		expect(String.isEmptyOrWhitespaceOrNil("  \t")).toEqual(true)
	end)

	it("returns false for a string with content", function()
		expect(String.isEmptyOrWhitespaceOrNil("hello")).toEqual(false)
	end)
end)

describe("String.elipseLimit", function()
	it("truncates and appends an ellipsis when over the limit", function()
		expect(String.elipseLimit("hello world", 8)).toEqual("hello...")
	end)

	it("leaves a string at or under the limit untouched", function()
		expect(String.elipseLimit("hello", 8)).toEqual("hello")
	end)

	it("produces a result of exactly the limit length", function()
		expect(#String.elipseLimit("abcdefghij", 8)).toEqual(8)
	end)
end)

describe("String.removePrefix", function()
	it("removes a matching prefix", function()
		expect(String.removePrefix("foobar", "foo")).toEqual("bar")
	end)

	it("returns the string unchanged when the prefix does not match", function()
		expect(String.removePrefix("foobar", "xyz")).toEqual("foobar")
	end)
end)

describe("String.removePostfix", function()
	it("removes a matching postfix", function()
		expect(String.removePostfix("foobar", "bar")).toEqual("foo")
	end)

	it("returns the string unchanged when the postfix does not match", function()
		expect(String.removePostfix("foobar", "xyz")).toEqual("foobar")
	end)
end)

describe("String.startsWith", function()
	it("returns true when the string starts with the prefix", function()
		expect(String.startsWith("foobar", "foo")).toEqual(true)
	end)

	it("returns false when the string does not start with the prefix", function()
		expect(String.startsWith("foobar", "bar")).toEqual(false)
	end)
end)

describe("String.endsWith", function()
	it("returns true when the string ends with the postfix", function()
		expect(String.endsWith("foobar", "bar")).toEqual(true)
	end)

	it("returns false when the string does not end with the postfix", function()
		expect(String.endsWith("foobar", "foo")).toEqual(false)
	end)
end)

describe("String.addCommas", function()
	it("adds commas to a large number", function()
		expect(String.addCommas(1000000)).toEqual("1,000,000")
	end)

	it("leaves numbers under a thousand unchanged", function()
		expect(String.addCommas(123)).toEqual("123")
	end)

	it("handles negative numbers", function()
		expect(String.addCommas(-1234567)).toEqual("-1,234,567")
	end)

	it("accepts a string number", function()
		expect(String.addCommas("1234567")).toEqual("1,234,567")
	end)

	it("uses a custom separator", function()
		expect(String.addCommas(1234, ".")).toEqual("1.234")
	end)
end)
