--!nonstrict
--[[
	@class InputTypeUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local InputTypeUtils = require("InputTypeUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("InputTypeUtils.isTapInWorld(inputKey)", function()
	it("should return true for Tap", function()
		expect(InputTypeUtils.isTapInWorld("Tap")).toEqual(true)
	end)

	it("should return false for other strings", function()
		expect(InputTypeUtils.isTapInWorld("other")).toEqual(false)
	end)
end)

describe("InputTypeUtils.isDrag(inputKey)", function()
	it("should return true for Drag", function()
		expect(InputTypeUtils.isDrag("Drag")).toEqual(true)
	end)

	it("should return false for other strings", function()
		expect(InputTypeUtils.isDrag("other")).toEqual(false)
	end)
end)

describe("InputTypeUtils.isRobloxTouchButton(inputKey)", function()
	it("should return true for TouchButton", function()
		expect(InputTypeUtils.isRobloxTouchButton("TouchButton")).toEqual(true)
	end)

	it("should return false for other strings", function()
		expect(InputTypeUtils.isRobloxTouchButton("other")).toEqual(false)
	end)
end)
