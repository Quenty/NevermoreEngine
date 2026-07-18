--!strict
--[[
	@class RogueMultiplier.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Jest = require("Jest")
local RogueMultiplier = require("RogueMultiplier")
local RoguePropertyModifierData = require("RoguePropertyModifierData")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local RogueMultiplierClass = RogueMultiplier:GetConstructor() :: any

-- Only TieRealmService is needed to construct a modifier directly; we do not start the
-- modifier binders, so this file never binds instances.
local function setup()
	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("TieRealmService"))
	serviceBag:Init()
	serviceBag:Start()

	local function newMultiplier(value)
		local valueObject = Instance.new("NumberValue")
		valueObject.Value = value
		return RogueMultiplierClass.new(valueObject, serviceBag), valueObject
	end

	return {
		newMultiplier = newMultiplier,
		destroy = function(_self: any)
			serviceBag:Destroy()
		end,
	}
end

local function setEnabled(valueObject, enabled)
	RoguePropertyModifierData:Create(valueObject).Enabled.Value = enabled
end

describe("RogueMultiplier binder surface", function()
	it("should be a Binder", function()
		expect(Binder.isBinder(RogueMultiplier)).toEqual(true)
	end)

	it("should be tagged 'RogueMultiplier'", function()
		expect(RogueMultiplier:GetTag()).toEqual("RogueMultiplier")
	end)

	it("should construct instances with the RogueMultiplier class name", function()
		expect(RogueMultiplierClass.ClassName).toEqual("RogueMultiplier")
	end)
end)

describe("RogueMultiplier:GetModifiedVersion()", function()
	it("should multiply the input by its value", function()
		local controller = setup()
		local modifier = controller.newMultiplier(2)
		expect(modifier:GetModifiedVersion(10)).toEqual(20)
		expect(modifier:GetModifiedVersion(2.5)).toEqual(5)
		controller:destroy()
	end)

	it("should reflect a later change to its value", function()
		local controller = setup()
		local modifier, valueObject = controller.newMultiplier(2)
		expect(modifier:GetModifiedVersion(10)).toEqual(20)
		valueObject.Value = 5
		expect(modifier:GetModifiedVersion(10)).toEqual(50)
		controller:destroy()
	end)

	it("should pass the input through unchanged when disabled", function()
		local controller = setup()
		local modifier, valueObject = controller.newMultiplier(2)
		setEnabled(valueObject, false)
		expect(modifier:GetModifiedVersion(10)).toEqual(10)
		controller:destroy()
	end)

	it("should scale a Color3 input by its value", function()
		local controller = setup()
		local modifier = controller.newMultiplier(2)
		expect(modifier:GetModifiedVersion(Color3.new(0.25, 0.25, 0.25))).toEqual(Color3.new(0.5, 0.5, 0.5))
		controller:destroy()
	end)
end)

describe("RogueMultiplier:GetInvertedVersion()", function()
	it("should divide the input by its value", function()
		local controller = setup()
		local modifier = controller.newMultiplier(2)
		expect(modifier:GetInvertedVersion(20)).toEqual(10)
		controller:destroy()
	end)

	it("should pass the input through unchanged when disabled", function()
		local controller = setup()
		local modifier, valueObject = controller.newMultiplier(2)
		setEnabled(valueObject, false)
		expect(modifier:GetInvertedVersion(20)).toEqual(20)
		controller:destroy()
	end)
end)
