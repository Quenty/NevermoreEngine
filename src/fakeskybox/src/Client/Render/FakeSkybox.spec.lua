--!nonstrict
--[[
	@class FakeSkybox.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local FakeSkybox = require("FakeSkybox")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("FakeSkybox", function()
	it("should be requireable", function()
		expect(FakeSkybox).never.toBeNil()
	end)

	it("should have ClassName set to FakeSkybox", function()
		expect(FakeSkybox.ClassName).toEqual("FakeSkybox")
	end)

	it("should have a new constructor", function()
		expect(typeof(FakeSkybox.new)).toEqual("function")
	end)
end)
