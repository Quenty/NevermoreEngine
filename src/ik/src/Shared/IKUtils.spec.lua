--!nonstrict
--[[
	@class IKUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local IKUtils = require("IKUtils")
local Jest = require("Jest")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("IKUtils.getDampenedAngleClamp(maxAngle, dampenAreaAngle)", function()
	it("should return a function", function()
		local clamp = IKUtils.getDampenedAngleClamp(90, 10)
		expect(type(clamp)).toEqual("function")
	end)

	it("should return 0 for input of 0", function()
		local clamp = IKUtils.getDampenedAngleClamp(90, 10)
		expect(clamp(0)).toEqual(0)
	end)

	it("should pass through angles within the undampened range", function()
		local clamp = IKUtils.getDampenedAngleClamp(90, 10)
		expect(clamp(50)).toEqual(50)
	end)
end)
