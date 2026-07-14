--!nonstrict
--[[
	@class RogueAdditive.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Jest = require("Jest")
local RogueAdditive = require("RogueAdditive")
local RoguePropertyModifierData = require("RoguePropertyModifierData")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local RogueAdditiveClass = RogueAdditive:GetConstructor()

-- Only TieRealmService is needed to construct a modifier directly; we do not start the
-- modifier binders, so this file never binds instances.
local function setup()
	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("TieRealmService"))
	serviceBag:Init()
	serviceBag:Start()

	local function newAdditive(className, value)
		local valueObject = Instance.new(className)
		valueObject.Value = value
		return RogueAdditiveClass.new(valueObject, serviceBag), valueObject
	end

	return {
		newAdditive = newAdditive,
		destroy = function()
			serviceBag:Destroy()
		end,
	}
end

local function setEnabled(valueObject, enabled)
	RoguePropertyModifierData:Create(valueObject).Enabled.Value = enabled
end

describe("RogueAdditive binder surface", function()
	it("should be a Binder", function()
		expect(Binder.isBinder(RogueAdditive)).toEqual(true)
	end)

	it("should be tagged 'RogueAdditive'", function()
		expect(RogueAdditive:GetTag()).toEqual("RogueAdditive")
	end)

	it("should construct instances with the RogueAdditive class name", function()
		expect(RogueAdditiveClass.ClassName).toEqual("RogueAdditive")
	end)
end)

describe("RogueAdditive:GetModifiedVersion()", function()
	it("should add its value to the input", function()
		local controller = setup()
		local modifier = controller.newAdditive("NumberValue", 15)
		expect(modifier:GetModifiedVersion(100)).toEqual(115)
		controller:destroy()
	end)

	it("should add component-wise for a Vector3 value", function()
		local controller = setup()
		local modifier = controller.newAdditive("Vector3Value", Vector3.new(1, 1, 1))
		expect(modifier:GetModifiedVersion(Vector3.new(2, 2, 2))).toEqual(Vector3.new(3, 3, 3))
		controller:destroy()
	end)

	it("should add component-wise for a Color3 value", function()
		local controller = setup()
		local modifier = controller.newAdditive("Color3Value", Color3.new(0.25, 0.25, 0.25))
		expect(modifier:GetModifiedVersion(Color3.new(0.5, 0.5, 0.5))).toEqual(Color3.new(0.75, 0.75, 0.75))
		controller:destroy()
	end)

	it("should reflect a later change to its value", function()
		local controller = setup()
		local modifier, valueObject = controller.newAdditive("NumberValue", 15)
		expect(modifier:GetModifiedVersion(100)).toEqual(115)
		valueObject.Value = 5
		expect(modifier:GetModifiedVersion(100)).toEqual(105)
		controller:destroy()
	end)

	it("should pass the input through unchanged when disabled", function()
		local controller = setup()
		local modifier, valueObject = controller.newAdditive("NumberValue", 15)
		setEnabled(valueObject, false)
		expect(modifier:GetModifiedVersion(100)).toEqual(100)
		controller:destroy()
	end)
end)

describe("RogueAdditive:GetInvertedVersion()", function()
	it("should subtract its value from the input", function()
		local controller = setup()
		local modifier = controller.newAdditive("NumberValue", 15)
		expect(modifier:GetInvertedVersion(115)).toEqual(100)
		controller:destroy()
	end)

	it("should pass the input through unchanged when disabled", function()
		local controller = setup()
		local modifier, valueObject = controller.newAdditive("NumberValue", 15)
		setEnabled(valueObject, false)
		expect(modifier:GetInvertedVersion(115)).toEqual(115)
		controller:destroy()
	end)
end)
