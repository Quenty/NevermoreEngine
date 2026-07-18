--!strict
--[[
	@class RogueSetter.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Jest = require("Jest")
local RoguePropertyModifierData = require("RoguePropertyModifierData")
local RogueSetter = require("RogueSetter")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local RogueSetterClass = RogueSetter:GetConstructor() :: any

-- Only TieRealmService is needed to construct a modifier directly; we do not start the
-- modifier binders, so this file never binds instances.
local function setup()
	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("TieRealmService"))
	serviceBag:Init()
	serviceBag:Start()

	local function newSetter(className, value)
		local valueObject: any = Instance.new(className)
		valueObject.Value = value
		return RogueSetterClass.new(valueObject, serviceBag), valueObject
	end

	return {
		newSetter = newSetter,
		destroy = function(_self: any)
			serviceBag:Destroy()
		end,
	}
end

local function setEnabled(valueObject, enabled)
	RoguePropertyModifierData:Create(valueObject).Enabled.Value = enabled
end

describe("RogueSetter binder surface", function()
	it("should be a Binder", function()
		expect(Binder.isBinder(RogueSetter)).toEqual(true)
	end)

	it("should be tagged 'RogueSetter'", function()
		expect(RogueSetter:GetTag()).toEqual("RogueSetter")
	end)

	it("should construct instances with the RogueSetter class name", function()
		expect(RogueSetterClass.ClassName).toEqual("RogueSetter")
	end)
end)

describe("RogueSetter:GetModifiedVersion()", function()
	it("should override the input with its value", function()
		local controller = setup()
		local modifier = controller.newSetter("NumberValue", 999)
		expect(modifier:GetModifiedVersion(10)).toEqual(999)
		expect(modifier:GetModifiedVersion(500)).toEqual(999)
		controller:destroy()
	end)

	it("should reflect a later change to its value", function()
		local controller = setup()
		local modifier, valueObject = controller.newSetter("NumberValue", 999)
		expect(modifier:GetModifiedVersion(10)).toEqual(999)
		valueObject.Value = 5
		expect(modifier:GetModifiedVersion(10)).toEqual(5)
		controller:destroy()
	end)

	it("should pass the input through unchanged when disabled", function()
		local controller = setup()
		local modifier, valueObject = controller.newSetter("NumberValue", 999)
		setEnabled(valueObject, false)
		expect(modifier:GetModifiedVersion(10)).toEqual(10)
		controller:destroy()
	end)
end)

describe("RogueSetter value types", function()
	it("should return a Color3 value", function()
		local controller = setup()
		local modifier = controller.newSetter("Color3Value", Color3.new(1, 0, 0))
		expect(modifier:GetModifiedVersion(Color3.new(0, 0, 0))).toEqual(Color3.new(1, 0, 0))
		controller:destroy()
	end)

	it("should return a boolean value", function()
		local controller = setup()
		local modifier = controller.newSetter("BoolValue", true)
		expect(modifier:GetModifiedVersion(false)).toEqual(true)
		controller:destroy()
	end)
end)

describe("RogueSetter:GetInvertedVersion()", function()
	it("should return the initial value", function()
		local controller = setup()
		local modifier = controller.newSetter("NumberValue", 999)
		expect(modifier:GetInvertedVersion(50, 7)).toEqual(7)
		controller:destroy()
	end)

	it("should pass the input through unchanged when disabled", function()
		local controller = setup()
		local modifier, valueObject = controller.newSetter("NumberValue", 999)
		setEnabled(valueObject, false)
		expect(modifier:GetInvertedVersion(50, 7)).toEqual(50)
		controller:destroy()
	end)
end)
