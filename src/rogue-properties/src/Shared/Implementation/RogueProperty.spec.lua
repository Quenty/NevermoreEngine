--!strict
--[[
	@class RogueProperty.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RoguePropertyArrayUtils = require("RoguePropertyArrayUtils")
local RoguePropertyConstants = require("RoguePropertyConstants")
local RoguePropertyModifierData = require("RoguePropertyModifierData")
local RoguePropertyTableDefinition = require("RoguePropertyTableDefinition")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("RoguePropertyService"))
	serviceBag:Init()
	serviceBag:Start()

	-- Adornees must live in the DataModel or CollectionService.GetInstanceAddedSignal (and
	-- therefore the modifier binders) never fire.
	local container = Instance.new("Folder")
	container.Name = "RoguePropertySpecContainer"
	container.Parent = workspace

	local additiveBinder = serviceBag:GetService(require("RogueAdditive"))
	local multiplierBinder = serviceBag:GetService(require("RogueMultiplier"))
	local setterBinder = serviceBag:GetService(require("RogueSetter"))

	local function newCombatStats()
		local definition = RoguePropertyTableDefinition.new("CombatStats", {
			Health = 100,
			Ultimate = {
				AttackDamage = 30,
				AbilityPower = 30,
			},
			ReticleHairRotationsDegree = { 0, 120, 240 },
		})

		local adornee = Instance.new("Folder")
		adornee.Parent = container
		return definition:GetPropertyTable(serviceBag, adornee), adornee
	end

	local function newArrayStats()
		local definition = RoguePropertyTableDefinition.new("ArrayStats", {
			Numbers = { 0, 120, 240 },
			Sequence = {
				{ Name = "One", Power = 1 },
				{ Name = "Two", Power = 2 },
			},
			Nested = {
				Inner = { 1, 2, 3 },
			},
		})

		local adornee = Instance.new("Folder")
		adornee.Parent = container
		return definition:GetPropertyTable(serviceBag, adornee), adornee
	end

	local function newTypedStats()
		local definition = RoguePropertyTableDefinition.new("TypedStats", {
			Color = Color3.new(1, 0, 0),
			Flag = true,
		})

		local adornee = Instance.new("Folder")
		adornee.Parent = container
		return definition:GetPropertyTable(serviceBag, adornee), adornee
	end

	local function modifierData(modifier)
		return RoguePropertyModifierData:Create(modifier)
	end

	local function awaitBound(binder, modifier)
		local ok = binder:Promise(modifier):Yield()
		assert(ok, "Modifier instance was never bound")
		return modifier
	end

	local function addMultiplier(prop, amount, source)
		local modifier = assert(prop:CreateMultiplier(amount, source), "Failed to create multiplier")
		return awaitBound(multiplierBinder, modifier)
	end

	local function addAdditive(prop, amount, source)
		local modifier = assert(prop:CreateAdditive(amount, source), "Failed to create additive")
		return awaitBound(additiveBinder, modifier)
	end

	local function addSetter(prop, value, source)
		local modifier = assert(prop:CreateSetter(value, source), "Failed to create setter")
		return awaitBound(setterBinder, modifier)
	end

	local function awaitValue(observable, predicate)
		local ok, value = Rx.toPromise((observable :: any):Pipe({
			Rx.where(predicate),
		})):Yield()
		assert(ok, "Observable never emitted a matching value")
		return value
	end

	return {
		serviceBag = serviceBag,
		container = container,
		newCombatStats = newCombatStats,
		newArrayStats = newArrayStats,
		newTypedStats = newTypedStats,
		modifierData = modifierData,
		addMultiplier = addMultiplier,
		addAdditive = addAdditive,
		addSetter = addSetter,
		awaitValue = awaitValue,
		destroy = function(_self: any)
			serviceBag:Destroy()
			container:Destroy()
		end,
	}
end

describe("RogueProperty scalar usage", function()
	it("should return the default base value", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		expect(properties.Health:GetBaseValue()).toEqual(100)
		controller:destroy()
	end)

	it("should expose the value through the .Value getter", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		expect(properties.Health.Value).toEqual(100)
		controller:destroy()
	end)

	it("should update the base value through SetBaseValue", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		properties.Health:SetBaseValue(42)
		expect(properties.Health:GetBaseValue()).toEqual(42)
		expect(properties.Health.Value).toEqual(42)
		controller:destroy()
	end)

	it("should update the value through the .Value setter", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		properties.Health.Value = 25
		expect(properties.Health.Value).toEqual(25)
		controller:destroy()
	end)

	it("should throw when assigning a value of the wrong type", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		expect(function()
			properties.Health.Value = "not a number"
		end).toThrow()
		controller:destroy()
	end)

	it("should return the same cached observable on repeated Observe calls", function()
		-- Exercises the rawget-backed observe cache. A dropped rawget would route this
		-- through __index and throw "Bad index".
		local controller = setup()
		local properties = controller.newCombatStats()
		local health = properties.Health
		expect(health:Observe()).toEqual(health:Observe())
		controller:destroy()
	end)

	it("should expose a Changed event", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		expect(properties.Health.Changed).never.toBeNil()
		controller:destroy()
	end)

	it("should return the same value across repeated reads", function()
		-- Exercises the rawget-backed base value instance cache.
		local controller = setup()
		local properties = controller.newCombatStats()
		expect(properties.Health.Value).toEqual(100)
		expect(properties.Health.Value).toEqual(100)
		controller:destroy()
	end)
end)

describe("RoguePropertyTable usage", function()
	it("should return the default base values as a table", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		local base = properties:GetBaseValue()
		expect(base.Health).toEqual(100)
		expect(base.Ultimate.AttackDamage).toEqual(30)
		expect(base.Ultimate.AbilityPower).toEqual(30)
		controller:destroy()
	end)

	it("should compute the current value table", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		local value = properties.Value
		expect(value.Health).toEqual(100)
		expect(value.Ultimate.AttackDamage).toEqual(30)
		controller:destroy()
	end)

	it("should apply a partial SetBaseValue without touching other members", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		properties:SetBaseValue({ Health = 5 })
		expect(properties.Health.Value).toEqual(5)
		expect(properties.Ultimate.AttackDamage.Value).toEqual(30)
		controller:destroy()
	end)

	it("should apply a whole-table assignment through the .Value setter", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		properties.Value = { Health = 25000 }
		expect(properties.Health.Value).toEqual(25000)
		controller:destroy()
	end)

	it("should read and write nested properties", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		expect(properties.Ultimate.AttackDamage.Value).toEqual(30)
		properties.Ultimate.AttackDamage.Value = 99
		expect(properties.Ultimate.AttackDamage.Value).toEqual(99)
		controller:destroy()
	end)
end)

describe("RogueProperty Color3 and boolean values", function()
	it("should round-trip a Color3 base value", function()
		local controller = setup()
		local properties = controller.newTypedStats()
		expect(properties.Color.Value).toEqual(Color3.new(1, 0, 0))
		properties.Color.Value = Color3.new(0, 0.5, 0.25)
		expect(properties.Color.Value).toEqual(Color3.new(0, 0.5, 0.25))
		controller:destroy()
	end)

	it("should round-trip a boolean base value", function()
		local controller = setup()
		local properties = controller.newTypedStats()
		expect(properties.Flag.Value).toEqual(true)
		properties.Flag.Value = false
		expect(properties.Flag.Value).toEqual(false)
		controller:destroy()
	end)

	it("should override a Color3 with a setter modifier", function()
		local controller = setup()
		local properties, adornee = controller.newTypedStats()
		controller.addSetter(properties.Color, Color3.new(0, 0, 1), adornee)
		expect(properties.Color.Value).toEqual(Color3.new(0, 0, 1))
		controller:destroy()
	end)

	it("should override a boolean with a setter modifier", function()
		local controller = setup()
		local properties, adornee = controller.newTypedStats()
		expect(properties.Flag.Value).toEqual(true)
		controller.addSetter(properties.Flag, false, adornee)
		expect(properties.Flag.Value).toEqual(false)
		controller:destroy()
	end)
end)

describe("RoguePropertyTable scalar arrays", function()
	it("should read the default array values", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		local value = properties.Numbers.Value
		expect(#value).toEqual(3)
		expect(value[1]).toEqual(0)
		expect(value[2]).toEqual(120)
		expect(value[3]).toEqual(240)
		controller:destroy()
	end)

	it("should expose the default array through GetBaseValue", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		local value = properties.Numbers:GetBaseValue()
		expect(#value).toEqual(3)
		expect(value[1]).toEqual(0)
		expect(value[3]).toEqual(240)
		controller:destroy()
	end)

	it("should include the array in the parent table's base value", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		local base = properties:GetBaseValue()
		expect(#base.Numbers).toEqual(3)
		expect(base.Numbers[2]).toEqual(120)
		controller:destroy()
	end)

	it("should expose each element as a RogueProperty by numeric index", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		expect(properties.Numbers[1].Value).toEqual(0)
		expect(properties.Numbers[2].Value).toEqual(120)
		expect(properties.Numbers[3].Value).toEqual(240)
		controller:destroy()
	end)

	it("should throw when indexing an element out of range", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		expect(function()
			return properties.Numbers[99]
		end).toThrow()
		controller:destroy()
	end)

	it("should report the array elements through GetRogueProperties", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		local rogueProperties = properties.Numbers:GetRogueProperties()
		local count = 0
		for _ in rogueProperties do
			count += 1
		end
		expect(count).toEqual(3)
		controller:destroy()
	end)

	it("should grow the array through the parent table's base value", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		properties:SetBaseValue({ Numbers = { 5, 10, 15, 20, 25 } })
		local value = properties.Numbers.Value
		expect(#value).toEqual(5)
		expect(value[1]).toEqual(5)
		expect(value[5]).toEqual(25)
		controller:destroy()
	end)

	it("should shrink the array through the .Value setter", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		properties.Numbers.Value = { 2, 5 }
		local value = properties.Numbers.Value
		expect(#value).toEqual(2)
		expect(value[1]).toEqual(2)
		expect(value[2]).toEqual(5)
		controller:destroy()
	end)

	it("should replace the array with a single element", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		properties.Numbers.Value = { 9 }
		local value = properties.Numbers.Value
		expect(#value).toEqual(1)
		expect(value[1]).toEqual(9)
		controller:destroy()
	end)

	it("should update a single element through its .Value setter", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		properties.Numbers[1].Value = 42
		expect(properties.Numbers[1].Value).toEqual(42)
		expect(properties.Numbers.Value[1]).toEqual(42)
		controller:destroy()
	end)
end)

describe("RoguePropertyTable table arrays", function()
	it("should read the default array of tables", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		local value = properties.Sequence.Value
		expect(#value).toEqual(2)
		expect(value[1].Name).toEqual("One")
		expect(value[1].Power).toEqual(1)
		expect(value[2].Name).toEqual("Two")
		controller:destroy()
	end)

	it("should expose each table element and its fields by index", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		expect(properties.Sequence[1].Name.Value).toEqual("One")
		expect(properties.Sequence[1].Power.Value).toEqual(1)
		expect(properties.Sequence[2].Name.Value).toEqual("Two")
		controller:destroy()
	end)

	it("should replace the table array through the .Value setter", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		properties.Sequence.Value = {
			{ Name = "Solo", Power = 9 },
		}
		local value = properties.Sequence.Value
		expect(#value).toEqual(1)
		expect(value[1].Name).toEqual("Solo")
		expect(value[1].Power).toEqual(9)
		controller:destroy()
	end)

	it("should update a field on a table element", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		properties.Sequence[1].Power.Value = 100
		expect(properties.Sequence[1].Power.Value).toEqual(100)
		controller:destroy()
	end)
end)

describe("RoguePropertyTable nested arrays", function()
	it("should read an array nested inside a table member", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		local value = properties.Nested.Inner.Value
		expect(#value).toEqual(3)
		expect(value[1]).toEqual(1)
		expect(value[3]).toEqual(3)
		controller:destroy()
	end)

	it("should set an array nested inside a table member", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		properties.Nested.Inner.Value = { 7, 8 }
		local value = properties.Nested.Inner.Value
		expect(#value).toEqual(2)
		expect(value[1]).toEqual(7)
		controller:destroy()
	end)
end)

describe("RoguePropertyTable array reactiveness", function()
	it("should observe the current array values", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		local value = controller.awaitValue(properties.Numbers:Observe(), function(v)
			return type(v) == "table" and #v == 3
		end)
		expect(value[1]).toEqual(0)
		expect(value[3]).toEqual(240)
		controller:destroy()
	end)

	it("should re-emit array values after a replacement", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		controller.awaitValue(properties.Numbers:Observe(), function(v)
			return type(v) == "table" and #v == 3
		end)

		properties.Numbers.Value = { 11, 22 }
		local value = controller.awaitValue(properties.Numbers:Observe(), function(v)
			return type(v) == "table" and #v == 2
		end)
		expect(value[1]).toEqual(11)
		expect(value[2]).toEqual(22)
		controller:destroy()
	end)
end)

-- Scalar array elements are serialized either as attributes on the container or as child
-- ValueBase instances, depending on when/how a game wrote them. Both forms exist in live
-- data, so reads must handle both. These lock that in.
describe("RoguePropertyTable scalar array serialization forms", function()
	it("should read scalar elements serialized as attributes", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		local container = properties.Numbers:GetContainer()
		container:SetAttribute(RoguePropertyArrayUtils.getNameFromIndex(1), 11)
		container:SetAttribute(RoguePropertyArrayUtils.getNameFromIndex(2), 22)

		local value = properties.Numbers.Value
		expect(#value).toEqual(3)
		expect(value[1]).toEqual(11)
		expect(value[2]).toEqual(22)
		expect(value[3]).toEqual(240)
		controller:destroy()
	end)

	it("should read scalar elements serialized as instances", function()
		local controller = setup()
		local properties = controller.newArrayStats()
		local container = properties.Numbers:GetContainer()
		for i, v in { 77, 88, 99 } do
			local name = RoguePropertyArrayUtils.getNameFromIndex(i)
			container:SetAttribute(name, RoguePropertyConstants.INSTANCE_ATTRIBUTE_VALUE)
			local numberValue = Instance.new("NumberValue")
			numberValue.Name = name
			numberValue.Value = v
			numberValue.Parent = container
		end

		local value = properties.Numbers.Value
		expect(#value).toEqual(3)
		expect(value[1]).toEqual(77)
		expect(value[2]).toEqual(88)
		expect(value[3]).toEqual(99)
		controller:destroy()
	end)
end)

describe("RoguePropertyTable edge cases", function()
	it("should throw when indexing a member that does not exist", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		expect(function()
			return properties.Nonexistent
		end).toThrow()
		controller:destroy()
	end)

	it("should throw when assigning to a reserved method name", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		expect(function()
			properties.GetValue = 1
		end).toThrow()
		controller:destroy()
	end)

	it("should throw when assigning to the Changed event", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		expect(function()
			properties.Changed = 1
		end).toThrow()
		controller:destroy()
	end)

	it("should throw when SetBaseValue includes an unexpected member", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		expect(function()
			properties:SetBaseValue({ Bogus = 1 })
		end).toThrow()
		controller:destroy()
	end)
end)

describe("RogueProperty modifiers (individual)", function()
	it("should apply a multiplier to the computed value", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		controller.addMultiplier(properties.Health, 2, adornee)
		expect(properties.Health.Value).toEqual(200)
		controller:destroy()
	end)

	it("should apply an additive to the computed value", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		controller.addAdditive(properties.Health, 15, adornee)
		expect(properties.Health.Value).toEqual(115)
		controller:destroy()
	end)

	it("should override the computed value with a setter", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		controller.addSetter(properties.Health, 777, adornee)
		expect(properties.Health.Value).toEqual(777)
		controller:destroy()
	end)

	it("should leave the base value unchanged when a modifier is applied", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		controller.addMultiplier(properties.Health, 2, adornee)
		expect(properties.Health:GetBaseValue()).toEqual(100)
		controller:destroy()
	end)
end)

describe("RogueProperty modifier ordering", function()
	it("should apply additive before multiplier by default: (base + add) * mult", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		local health = properties.Health

		controller.addAdditive(health, 10, adornee) -- Order 1
		controller.addMultiplier(health, 2, adornee) -- Order 2

		expect(health.Value).toEqual(220)
		controller:destroy()
	end)

	it("should respect a reordered additive: base * mult + add", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		local health = properties.Health

		local additive = controller.addAdditive(health, 10, adornee)
		controller.addMultiplier(health, 2, adornee) -- Order 2

		controller.modifierData(additive).Order.Value = 5

		expect(health.Value).toEqual(210)
		controller:destroy()
	end)

	it("should stack setter, additive, and multiplier in order", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		local health = properties.Health

		controller.addSetter(health, 50, adornee) -- Order 0, replaces running value
		controller.addAdditive(health, 10, adornee) -- Order 1
		controller.addMultiplier(health, 2, adornee) -- Order 2

		expect(health.Value).toEqual(120)
		controller:destroy()
	end)

	it("should stack two additives", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		local health = properties.Health

		controller.addAdditive(health, 10, adornee)
		controller.addAdditive(health, 5, adornee)

		expect(health.Value).toEqual(115)
		controller:destroy()
	end)
end)

describe("RogueProperty modifier enable/disable", function()
	it("should ignore a disabled modifier and re-apply it when re-enabled", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		local health = properties.Health

		local multiplier = controller.addMultiplier(health, 2, adornee)
		expect(health.Value).toEqual(200)

		controller.modifierData(multiplier).Enabled.Value = false
		expect(health.Value).toEqual(100)

		controller.modifierData(multiplier).Enabled.Value = true
		expect(health.Value).toEqual(200)

		controller:destroy()
	end)
end)

describe("RogueProperty reactiveness", function()
	it("should emit the current value on subscribe", function()
		local controller = setup()
		local properties = controller.newCombatStats()
		local value = controller.awaitValue(properties.Health:Observe(), function(v)
			return v == 100
		end)
		expect(value).toEqual(100)
		controller:destroy()
	end)

	it("should re-emit when a modifier is added", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		local health = properties.Health

		controller.addMultiplier(health, 2, adornee)

		local value = controller.awaitValue(health:Observe(), function(v)
			return v == 200
		end)
		expect(value).toEqual(200)
		controller:destroy()
	end)

	it("should re-emit when a modifier's value changes", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		local health = properties.Health

		local multiplier = controller.addMultiplier(health, 2, adornee)
		expect(controller.awaitValue(health:Observe(), function(v)
			return v == 200
		end)).toEqual(200)

		multiplier.Value = 3
		expect(controller.awaitValue(health:Observe(), function(v)
			return v == 300
		end)).toEqual(300)

		controller:destroy()
	end)

	it("should re-emit when a modifier is removed", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		local health = properties.Health

		local multiplier = controller.addMultiplier(health, 2, adornee)
		expect(controller.awaitValue(health:Observe(), function(v)
			return v == 200
		end)).toEqual(200)

		multiplier:Destroy()
		expect(controller.awaitValue(health:Observe(), function(v)
			return v == 100
		end)).toEqual(100)

		controller:destroy()
	end)

	it("should re-emit when the base value changes underneath a modifier", function()
		local controller = setup()
		local properties, adornee = controller.newCombatStats()
		local health = properties.Health

		controller.addMultiplier(health, 2, adornee)
		expect(controller.awaitValue(health:Observe(), function(v)
			return v == 200
		end)).toEqual(200)

		health:SetBaseValue(50)
		expect(controller.awaitValue(health:Observe(), function(v)
			return v == 100
		end)).toEqual(100)

		controller:destroy()
	end)
end)
