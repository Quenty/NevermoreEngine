--!nonstrict
--[[
	@class RogueModifierBase.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RogueModifierBase = require("RogueModifierBase")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local serviceBag = ServiceBag.new()
	serviceBag:GetService(require("TieRealmService"))
	serviceBag:Init()
	serviceBag:Start()

	local function newModifierBase(value)
		local valueObject = Instance.new("NumberValue")
		valueObject.Value = value
		return RogueModifierBase.new(valueObject, serviceBag), valueObject
	end

	return {
		newModifierBase = newModifierBase,
		destroy = function()
			serviceBag:Destroy()
		end,
	}
end

describe("RogueModifierBase", function()
	it("should have the RogueModifierBase class name", function()
		expect(RogueModifierBase.ClassName).toEqual("RogueModifierBase")
	end)

	it("should expose Order and Source data on construction", function()
		local controller = setup()
		local modifier = controller.newModifierBase(1)
		expect(modifier.Order).never.toBeNil()
		expect(modifier.Source).never.toBeNil()
		controller:destroy()
	end)

	it("should error from the unimplemented GetModifiedVersion", function()
		local controller = setup()
		local modifier = controller.newModifierBase(1)
		expect(function()
			modifier:GetModifiedVersion(1)
		end).toThrow()
		controller:destroy()
	end)

	it("should error from the unimplemented ObserveModifiedVersion", function()
		local controller = setup()
		local modifier = controller.newModifierBase(1)
		expect(function()
			modifier:ObserveModifiedVersion(1)
		end).toThrow()
		controller:destroy()
	end)
end)
