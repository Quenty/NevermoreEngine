--!strict
--[[
	@class MetricUnit.Roblox.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

describe("MetricUnit and the Roblox engine", function()
	it("converts Roblox mass units and stud accelerations through the documented stud and RMU", function()
		-- A Roblox mass unit is a cubic stud of water
		expect(MetricUnit.new(1, "robloxMassUnit"):In("kilogram")).toBeCloseTo(21.952, 9)
		expect(MetricUnit.new(196.2, "studPerSecondSquared"):In("meterPerSecondSquared")).toBeCloseTo(196.2 * 0.28, 9)
		-- An engine force is a mass times an acceleration, so it needs no unit of its own
		local force = MetricUnit.new(1, "robloxMassUnit") * MetricUnit.new(1, "studPerSecondSquared")
		expect(force:GetKind()).toBe("force")
		expect(force:In("newton")).toBeCloseTo(21.952 * 0.28, 9)
	end)

	it("reads a velocity's speed in studs per second", function()
		if typeof(Vector3) ~= "table" and typeof(Vector3) ~= "userdata" then
			return -- Vector3 exists in Roblox only
		end
		local speed = MetricUnit.fromStudVelocity(Vector3.new(3, 4, 0))
		expect(speed:In("studPerSecond")).toBeCloseTo(5, 9)
		expect(speed:In("meterPerSecond")).toBeCloseTo(5 * 0.28, 9)
	end)
end)
