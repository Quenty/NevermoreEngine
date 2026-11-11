--!strict
--[[
	@class RoguePropertyUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RoguePropertyUtils = require("RoguePropertyUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Minimal stand-in for a RoguePropertyDefinition so these stay pure unit tests.
local function fakeDefinition(valueType, defaultValue, encodedDefaultValue)
	return {
		GetValueType = function()
			return valueType
		end,
		GetName = function()
			return "Fake"
		end,
		GetDefaultValue = function()
			return defaultValue
		end,
		GetEncodedDefaultValue = function()
			return encodedDefaultValue
		end,
	}
end

describe("RoguePropertyUtils.encodeProperty()", function()
	it("should pass through a number unchanged", function()
		local definition = fakeDefinition("number", 0, 0)
		expect(RoguePropertyUtils.encodeProperty(definition, 42)).toEqual(42)
	end)

	it("should pass through a string unchanged", function()
		local definition = fakeDefinition("string", "", "")
		expect(RoguePropertyUtils.encodeProperty(definition, "hello")).toEqual("hello")
	end)

	it("should JSON-encode a table value", function()
		local definition = fakeDefinition("table", {}, "{}")
		local encoded = RoguePropertyUtils.encodeProperty(definition, { a = 1 })
		expect(encoded).toEqual(expect.any("string"))
	end)
end)

describe("RoguePropertyUtils.decodeProperty()", function()
	it("should pass through a number unchanged", function()
		local definition = fakeDefinition("number", 0, 0)
		expect(RoguePropertyUtils.decodeProperty(definition, 42)).toEqual(42)
	end)

	it("should round-trip a table value through encode then decode", function()
		local definition = fakeDefinition("table", {}, "{}")
		local original = { a = 1, b = 2 }
		local encoded = RoguePropertyUtils.encodeProperty(definition, original)
		local decoded = RoguePropertyUtils.decodeProperty(definition, encoded)
		expect(decoded).toEqual(original)
	end)

	it("should fall back to the default when decoding invalid JSON", function()
		local fallback = { fallback = true }
		local definition = fakeDefinition("table", fallback, "{}")
		local decoded = RoguePropertyUtils.decodeProperty(definition, "this is not json {{{")
		expect(decoded).toEqual(fallback)
	end)
end)
