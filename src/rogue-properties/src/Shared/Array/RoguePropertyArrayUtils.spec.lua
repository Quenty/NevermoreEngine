--!strict
--[[
	@class RoguePropertyArrayUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RoguePropertyArrayUtils = require("RoguePropertyArrayUtils")
local RoguePropertyConstants = require("RoguePropertyConstants")
local RoguePropertyTableDefinition = require("RoguePropertyTableDefinition")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function parentDefinition()
	return RoguePropertyTableDefinition.new("Parent")
end

describe("RoguePropertyArrayUtils.getNameFromIndex / getIndexFromName", function()
	it("should round-trip an index through a name", function()
		local name = RoguePropertyArrayUtils.getNameFromIndex(3)
		expect(RoguePropertyArrayUtils.getIndexFromName(name)).toEqual(3)
	end)

	it("should return nil for a name without the array prefix", function()
		expect(RoguePropertyArrayUtils.getIndexFromName("HasInitializedArrayComponent")).toBeNil()
		expect(RoguePropertyArrayUtils.getIndexFromName("SomeOtherName")).toBeNil()
	end)
end)

describe("RoguePropertyArrayUtils.createDefinitionsFromArrayData", function()
	it("should create one scalar definition per element", function()
		local definitions = RoguePropertyArrayUtils.createDefinitionsFromArrayData({ 10, 20, 30 }, parentDefinition())

		local count = 0
		for _ in definitions do
			count += 1
		end
		expect(count).toEqual(3)

		expect(definitions[1]:GetValueType()).toEqual("number")
		expect(definitions[1]:GetDefaultValue()).toEqual(10)
		expect(definitions[1]:GetName()).toEqual(RoguePropertyArrayUtils.getNameFromIndex(1))
		expect(definitions[3]:GetDefaultValue()).toEqual(30)
	end)

	it("should create table definitions for an array of tables", function()
		local definitions = RoguePropertyArrayUtils.createDefinitionsFromArrayData({
			{ Name = "One", Power = 1 },
			{ Name = "Two", Power = 2 },
		}, parentDefinition())

		expect(RoguePropertyTableDefinition.isRoguePropertyTableDefinition(definitions[1])).toEqual(true)
		expect(definitions[1]:GetDefinition("Name"):GetValueType()).toEqual("string")
	end)
end)

describe("RoguePropertyArrayUtils.createDefinitionsFromContainer", function()
	it("should discover elements serialized as ValueBase instances", function()
		local container = Instance.new("Folder")
		local child = Instance.new("NumberValue")
		child.Name = RoguePropertyArrayUtils.getNameFromIndex(1)
		child.Value = 5
		child.Parent = container

		local definitions = RoguePropertyArrayUtils.createDefinitionsFromContainer(container, parentDefinition())
		expect(definitions[1]:GetDefaultValue()).toEqual(5)
		expect(definitions[1]:GetValueType()).toEqual("number")
	end)

	it("should discover elements serialized as attributes", function()
		local container = Instance.new("Folder")
		container:SetAttribute(RoguePropertyArrayUtils.getNameFromIndex(1), 11)
		container:SetAttribute(RoguePropertyArrayUtils.getNameFromIndex(2), 22)

		local definitions = RoguePropertyArrayUtils.createDefinitionsFromContainer(container, parentDefinition())
		expect(definitions[1]:GetDefaultValue()).toEqual(11)
		expect(definitions[2]:GetDefaultValue()).toEqual(22)
	end)

	it("should ignore the initialization marker attribute", function()
		local container = Instance.new("Folder")
		container:SetAttribute("HasInitializedArrayComponent", true)

		local definitions = RoguePropertyArrayUtils.createDefinitionsFromContainer(container, parentDefinition())
		expect(next(definitions)).toBeNil()
	end)

	it("should ignore the instance sentinel attribute with no backing instance", function()
		local container = Instance.new("Folder")
		container:SetAttribute(
			RoguePropertyArrayUtils.getNameFromIndex(1),
			RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE
		)

		local definitions = RoguePropertyArrayUtils.createDefinitionsFromContainer(container, parentDefinition())
		expect(definitions[1]).toBeNil()
	end)

	it("should prefer the instance over the sentinel attribute for the same index", function()
		local container = Instance.new("Folder")
		local name = RoguePropertyArrayUtils.getNameFromIndex(1)

		local child = Instance.new("NumberValue")
		child.Name = name
		child.Value = 99
		child.Parent = container
		container:SetAttribute(name, RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE)

		local definitions = RoguePropertyArrayUtils.createDefinitionsFromContainer(container, parentDefinition())
		expect(definitions[1]:GetDefaultValue()).toEqual(99)
	end)
end)
