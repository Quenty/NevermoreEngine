--!nonstrict
--[[
	@class RoguePropertyDefinition.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RoguePropertyDefinition = require("RoguePropertyDefinition")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function makeDefinition(name, defaultValue)
	local definition = RoguePropertyDefinition.new()
	definition:SetName(name)
	definition:SetDefaultValue(defaultValue)
	return definition
end

describe("RoguePropertyDefinition.new()", function()
	it("should default to the name 'Unnamed'", function()
		local definition = RoguePropertyDefinition.new()
		expect(definition:GetName()).toEqual("Unnamed")
	end)

	it("should be recognized as a RoguePropertyDefinition", function()
		local definition = RoguePropertyDefinition.new()
		expect(RoguePropertyDefinition.isRoguePropertyDefinition(definition)).toEqual(true)
	end)
end)

describe("RoguePropertyDefinition.isRoguePropertyDefinition()", function()
	it("should return false for a plain table", function()
		expect(RoguePropertyDefinition.isRoguePropertyDefinition({})).toEqual(false)
	end)

	it("should return false for a non-table value", function()
		expect(RoguePropertyDefinition.isRoguePropertyDefinition("not a definition")).toEqual(false)
		expect(RoguePropertyDefinition.isRoguePropertyDefinition(nil)).toEqual(false)
	end)
end)

describe("RoguePropertyDefinition:SetName()", function()
	it("should store and return the name", function()
		local definition = RoguePropertyDefinition.new()
		definition:SetName("Health")
		expect(definition:GetName()).toEqual("Health")
	end)

	it("should reject a non-string name", function()
		local definition = RoguePropertyDefinition.new()
		expect(function()
			definition:SetName(5 :: any)
		end).toThrow()
	end)
end)

describe("RoguePropertyDefinition:SetDefaultValue()", function()
	it("should reject a nil default value", function()
		local definition = RoguePropertyDefinition.new()
		expect(function()
			definition:SetDefaultValue(nil)
		end).toThrow()
	end)

	it("should record the value type from the default", function()
		local definition = makeDefinition("Health", 100)
		expect(definition:GetValueType()).toEqual("number")
		expect(definition:GetDefaultValue()).toEqual(100)
	end)

	it("should encode primitive defaults to themselves", function()
		local definition = makeDefinition("Health", 100)
		expect(definition:GetEncodedDefaultValue()).toEqual(100)
	end)

	it("should re-derive the value type when reassigned", function()
		local definition = RoguePropertyDefinition.new()
		definition:SetDefaultValue(100)
		expect(definition:GetValueType()).toEqual("number")

		definition:SetDefaultValue("now a string")
		expect(definition:GetValueType()).toEqual("string")
		expect(definition:GetStorageInstanceType()).toEqual("StringValue")
	end)
end)

describe("RoguePropertyDefinition:GetStorageInstanceType()", function()
	it("should map number to NumberValue", function()
		expect(makeDefinition("N", 1):GetStorageInstanceType()).toEqual("NumberValue")
	end)

	it("should map string to StringValue", function()
		expect(makeDefinition("S", "hello"):GetStorageInstanceType()).toEqual("StringValue")
	end)

	it("should map boolean to BoolValue", function()
		expect(makeDefinition("B", false):GetStorageInstanceType()).toEqual("BoolValue")
	end)

	it("should map Color3 to Color3Value", function()
		expect(makeDefinition("C", Color3.new(1, 0, 0)):GetStorageInstanceType()).toEqual("Color3Value")
	end)

	it("should map BrickColor to BrickColorValue", function()
		expect(makeDefinition("BC", BrickColor.new("Bright red")):GetStorageInstanceType()).toEqual("BrickColorValue")
	end)

	it("should map Vector3 to Vector3Value", function()
		expect(makeDefinition("V", Vector3.new(1, 2, 3)):GetStorageInstanceType()).toEqual("Vector3Value")
	end)

	it("should map CFrame to CFrameValue", function()
		expect(makeDefinition("CF", CFrame.new()):GetStorageInstanceType()).toEqual("CFrameValue")
	end)

	it("should error for an unsupported value type", function()
		expect(function()
			makeDefinition("Bad", Vector2.new(1, 2))
		end).toThrow()
	end)
end)

describe("RoguePropertyDefinition:CanAssign()", function()
	it("should allow a value matching the default's type", function()
		local definition = makeDefinition("Health", 100)
		local canAssign = definition:CanAssign(50)
		expect(canAssign).toEqual(true)
	end)

	it("should reject a value of the wrong type and return a message", function()
		local definition = makeDefinition("Health", 100)
		local canAssign, message = definition:CanAssign("fifty")
		expect(canAssign).toEqual(false)
		expect(message).toEqual(expect.any("string"))
	end)

	it("should reject a nil assignment", function()
		local definition = makeDefinition("Health", 100)
		local canAssign = definition:CanAssign(nil)
		expect(canAssign).toEqual(false)
	end)
end)

describe("RoguePropertyDefinition:GetFullName()", function()
	it("should return the name when there is no parent", function()
		local definition = makeDefinition("Health", 100)
		expect(definition:GetFullName()).toEqual("Health")
	end)
end)
