--!strict
--[[
	@class MetricUnit.Angles.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local MetricUnit = require("MetricUnit")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Formatting puts a no-break space between a number and its unit; these compare it as a plain space
local function plain(text: string): string
	return (string.gsub(text, "\u{00A0}", " "))
end

local function format(value: any, options: MetricUnit.FormatOptions?): string
	return plain(MetricUnit.format(value, options))
end

describe("MetricUnit angles", function()
	it("converts between radians, degrees and revolutions", function()
		expect(MetricUnit.degrees(180):In("radian")).toBeCloseTo(math.pi, 12)
		expect(MetricUnit.new(1, "revolution"):In("degree")).toBeCloseTo(360, 9)
		expect(MetricUnit.fuzzyEq(MetricUnit.radians(math.pi), MetricUnit.degrees(180))).toBe(true)
		-- The bridge to CFrame.Angles and math.sin is reading radians
		expect(MetricUnit.degrees(90):In("radian")).toBeCloseTo(math.rad(90), 12)
		expect(MetricUnit.radians(math.rad(30)):In("degree")).toBeCloseTo(30, 9)
		expect(MetricUnit.degrees(1):GetKind()).toBe("angle")
	end)

	it("keeps angles apart from lengths", function()
		expect(function()
			local _ = MetricUnit.degrees(1) + MetricUnit.meters(1)
		end).toThrow("cannot add angle and length")
		expect(MetricUnit.sameDimension(MetricUnit.radians(1), MetricUnit.none(1))).toBe(false)
	end)

	it("reads angular velocity and acceleration", function()
		expect(MetricUnit.new(60, "revolutionPerMinute"):In("radianPerSecond")).toBeCloseTo(2 * math.pi, 9)
		expect(MetricUnit.new(360, "degreePerSecond"):In("revolutionPerMinute")).toBeCloseTo(60, 9)
		expect((MetricUnit.degrees(90) / MetricUnit.seconds(1)):GetKind()).toBe("angularVelocity")
		local spinUp = MetricUnit.new(4, "radianPerSecond") / MetricUnit.seconds(2)
		expect(spinUp:GetKind()).toBe("angularAcceleration")
		expect(spinUp:In("radianPerSecondSquared")).toBe(2)
	end)

	it("turns an angle into an arc length, and an angular speed into a speed", function()
		expect(MetricUnit.arcLength(MetricUnit.degrees(180), MetricUnit.meters(2)):In("meter")).toBeCloseTo(
			2 * math.pi,
			9
		)
		local rim = MetricUnit.arcLength(MetricUnit.new(60, "revolutionPerMinute"), MetricUnit.meters(1))
		expect(rim:GetKind()).toBe("speed")
		expect(rim:In("meterPerSecond")).toBeCloseTo(2 * math.pi, 9)
		expect(function()
			MetricUnit.arcLength(MetricUnit.meters(1), MetricUnit.meters(1))
		end).toThrow("takes an angle or an angle per time, not length")
	end)

	it("formats angles in degrees by default", function()
		expect(format(MetricUnit.degrees(45))).toBe("45°")
		expect(format(MetricUnit.radians(1))).toBe("57.296°")
		expect(format(MetricUnit.radians(1), { unit = "radian" })).toBe("1 rad")
		expect(format(MetricUnit.degrees(2), { unitDisplay = "long" })).toBe("2 degrees")
		expect(format(MetricUnit.degrees(1), { unitDisplay = "long" })).toBe("1 degree")
		expect(format(MetricUnit.new(60, "revolutionPerMinute"))).toBe("360 °/s")
		expect(format(MetricUnit.new(60, "revolutionPerMinute"), { unit = "revolutionPerMinute" })).toBe("60 rpm")
		expect(tostring(MetricUnit.degrees(45))).toBe("45°")
	end)
end)

describe("MetricUnit.arcLength with a plain zero radius", function()
	it("is zero", function()
		expect(MetricUnit.arcLength(MetricUnit.degrees(90), 0 :: any):In("meter")).toBe(0)
	end)
end)
