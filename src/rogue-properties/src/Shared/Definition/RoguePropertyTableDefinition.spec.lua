--!nonstrict
--[[
	@class RoguePropertyTableDefinition.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RoguePropertyTableDefinition = require("RoguePropertyTableDefinition")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function makeCombatStats()
	return RoguePropertyTableDefinition.new("CombatStats", {
		Health = 100,
		Ultimate = {
			AttackDamage = 30,
			AbilityPower = 30,
		},
		ReticleHairRotationsDegree = { 0, 120, 240 },
	})
end

describe("RoguePropertyTableDefinition.new()", function()
	it("should be recognized as a table definition", function()
		local definition = makeCombatStats()
		expect(RoguePropertyTableDefinition.isRoguePropertyTableDefinition(definition)).toEqual(true)
	end)

	it("should report that it has children", function()
		local definition = makeCombatStats()
		expect(definition:HasChildren()).toEqual(true)
	end)

	it("should store the provided name", function()
		local definition = makeCombatStats()
		expect(definition:GetName()).toEqual("CombatStats")
	end)

	it("should construct with no default value table", function()
		local definition = RoguePropertyTableDefinition.new("Empty")
		expect(definition:GetName()).toEqual("Empty")
	end)
end)

describe("RoguePropertyTableDefinition:GetDefinition()", function()
	it("should return a scalar definition for a scalar member", function()
		local definition = makeCombatStats()
		local health = definition:GetDefinition("Health")
		expect(health).never.toBeNil()
		expect(health:GetValueType()).toEqual("number")
	end)

	it("should return a table definition for a nested table member", function()
		local definition = makeCombatStats()
		local ultimate = definition:GetDefinition("Ultimate")
		expect(RoguePropertyTableDefinition.isRoguePropertyTableDefinition(ultimate)).toEqual(true)
	end)

	it("should return nil for a member that does not exist", function()
		local definition = makeCombatStats()
		expect(definition:GetDefinition("DoesNotExist")).toBeNil()
	end)
end)

describe("RoguePropertyTableDefinition full names", function()
	it("should qualify nested definitions with the parent name", function()
		local definition = makeCombatStats()
		local attackDamage = definition:GetDefinition("Ultimate"):GetDefinition("AttackDamage")
		expect(attackDamage:GetFullName()).toEqual("CombatStats.Ultimate.AttackDamage")
	end)
end)

describe("RoguePropertyTableDefinition array helper", function()
	it("should create an array helper for a numeric-index default", function()
		local definition = makeCombatStats()
		expect(definition:GetDefinitionArrayHelper()).toBeNil()
		local arrayDefinition = definition:GetDefinition("ReticleHairRotationsDegree")
		expect(arrayDefinition:GetDefinitionArrayHelper()).never.toBeNil()
	end)

	it("should retain the default array data", function()
		local definition = makeCombatStats()
		local helper = definition:GetDefinition("ReticleHairRotationsDegree"):GetDefinitionArrayHelper()
		expect(helper:IsArray()).toEqual(true)
		local data = helper:GetDefaultArrayData()
		expect(#data).toEqual(3)
		expect(data[1]).toEqual(0)
		expect(data[3]).toEqual(240)
	end)

	it("should produce one default definition per element", function()
		local definition = makeCombatStats()
		local helper = definition:GetDefinition("ReticleHairRotationsDegree"):GetDefinitionArrayHelper()
		local defaults = helper:GetDefaultDefinitions()

		local count = 0
		for _ in defaults do
			count += 1
		end
		expect(count).toEqual(3)
		expect(defaults[1]:GetValueType()).toEqual("number")
		expect(defaults[1]:GetDefaultValue()).toEqual(0)
		expect(defaults[3]:GetDefaultValue()).toEqual(240)
	end)

	it("should accept a valid array member and reject a wrong-typed one", function()
		local definition = makeCombatStats()
		local helper = definition:GetDefinition("ReticleHairRotationsDegree"):GetDefinitionArrayHelper()
		expect((helper:CanAssignAsArrayMember(5, false))).toEqual(true)
		expect((helper:CanAssignAsArrayMember("nope", false))).toEqual(false)
	end)
end)

describe("RoguePropertyTableDefinition table arrays", function()
	local function makeSequenceDefinition()
		return RoguePropertyTableDefinition.new("Ability", {
			Sequence = {
				{ Name = "One", Power = 1 },
				{ Name = "Two", Power = 2 },
			},
		})
	end

	it("should create an array helper for an array of tables", function()
		local definition = makeSequenceDefinition()
		local sequence = definition:GetDefinition("Sequence")
		expect(sequence:GetDefinitionArrayHelper()).never.toBeNil()
	end)

	it("should produce table definitions for each element", function()
		local definition = makeSequenceDefinition()
		local helper = definition:GetDefinition("Sequence"):GetDefinitionArrayHelper()
		local defaults = helper:GetDefaultDefinitions()
		expect(RoguePropertyTableDefinition.isRoguePropertyTableDefinition(defaults[1])).toEqual(true)
		expect(defaults[1]:GetDefinition("Name"):GetValueType()).toEqual("string")
		expect(defaults[1]:GetDefinition("Power"):GetValueType()).toEqual("number")
	end)
end)

describe("RoguePropertyTableDefinition:__index", function()
	it("should expose nested definitions by field access", function()
		local definition = makeCombatStats()
		expect(definition.Ultimate.AttackDamage:GetValueType()).toEqual("number")
	end)

	it("should throw when indexing a member that does not exist", function()
		local definition = makeCombatStats()
		expect(function()
			return definition.Nonexistent
		end).toThrow()
	end)
end)

describe("RoguePropertyTableDefinition:CanAssign() non-strict", function()
	it("should allow a partial assignment", function()
		local definition = makeCombatStats()
		local canAssign = definition:CanAssign({ Health = 50 }, false)
		expect(canAssign).toEqual(true)
	end)

	it("should allow a nested partial assignment", function()
		local definition = makeCombatStats()
		local canAssign = definition:CanAssign({
			Ultimate = { AttackDamage = 5 },
		}, false)
		expect(canAssign).toEqual(true)
	end)

	it("should reject a non-table value", function()
		local definition = makeCombatStats()
		local canAssign, message = definition:CanAssign(5, false)
		expect(canAssign).toEqual(false)
		expect(message).toEqual(expect.any("string"))
	end)

	it("should reject an unexpected member", function()
		local definition = makeCombatStats()
		local canAssign, message = definition:CanAssign({ NotAMember = 1 }, false)
		expect(canAssign).toEqual(false)
		expect(message).toEqual(expect.any("string"))
	end)

	it("should reject a member of the wrong type", function()
		local definition = makeCombatStats()
		local canAssign, message = definition:CanAssign({ Health = "lots" }, false)
		expect(canAssign).toEqual(false)
		expect(message).toEqual(expect.any("string"))
	end)
end)

describe("RoguePropertyTableDefinition:CanAssign() strict", function()
	it("should allow a fully specified assignment", function()
		local definition = RoguePropertyTableDefinition.new("Small", {
			Health = 100,
			Mana = 50,
		})
		local canAssign = definition:CanAssign({ Health = 1, Mana = 2 }, true)
		expect(canAssign).toEqual(true)
	end)

	it("should reject an assignment that is missing keys", function()
		local definition = RoguePropertyTableDefinition.new("Small", {
			Health = 100,
			Mana = 50,
		})
		local canAssign, message = definition:CanAssign({ Health = 1 }, true)
		expect(canAssign).toEqual(false)
		expect(message).toEqual(expect.any("string"))
	end)
end)

describe("RoguePropertyTableDefinition:CanAssign() arrays", function()
	it("should accept a valid replacement array", function()
		local definition = makeCombatStats()
		local arrayDefinition = definition:GetDefinition("ReticleHairRotationsDegree")
		local canAssign = arrayDefinition:CanAssign({ 1, 2, 3, 4 }, false)
		expect(canAssign).toEqual(true)
	end)

	it("should reject a string key on an array definition", function()
		local definition = makeCombatStats()
		local arrayDefinition = definition:GetDefinition("ReticleHairRotationsDegree")
		local canAssign, message = arrayDefinition:CanAssign({ Nope = 1 }, false)
		expect(canAssign).toEqual(false)
		expect(message).toEqual(expect.any("string"))
	end)

	it("should reject an array member of the wrong type", function()
		local definition = makeCombatStats()
		local arrayDefinition = definition:GetDefinition("ReticleHairRotationsDegree")
		local canAssign = arrayDefinition:CanAssign({ "not", "numbers" }, false)
		expect(canAssign).toEqual(false)
	end)
end)
