--!nonstrict
--[[
	@class BlendDefaultProps.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BlendDefaultProps = require("BlendDefaultProps")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("BlendDefaultProps", function()
	it("should have a ScreenGui key", function()
		expect(BlendDefaultProps.ScreenGui).never.toEqual(nil)
	end)

	it("should set ScreenGui.ResetOnSpawn to false", function()
		expect(BlendDefaultProps.ScreenGui.ResetOnSpawn).toEqual(false)
	end)

	it("should have a Frame key", function()
		expect(BlendDefaultProps.Frame).never.toEqual(nil)
	end)
end)
