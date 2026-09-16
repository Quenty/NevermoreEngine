--!strict
--[[
	@class Vector3Utils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Vector3Utils = require("Vector3Utils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local EPSILON = 1e-5

local function expectVector3Close(actual: Vector3, expected: Vector3)
	expect(actual.X).toBeCloseTo(expected.X, 5)
	expect(actual.Y).toBeCloseTo(expected.Y, 5)
	expect(actual.Z).toBeCloseTo(expected.Z, 5)
end

describe("Vector3Utils.volume", function()
	it("multiplies the three components", function()
		expect(Vector3Utils.volume(Vector3.new(2, 3, 4))).toBe(24)
	end)

	it("is non-negative when a component is negative", function()
		expect(Vector3Utils.volume(Vector3.new(-2, 3, 4))).toBe(24)
		expect(Vector3Utils.volume(Vector3.new(-2, -3, 4))).toBe(24)
		expect(Vector3Utils.volume(-Vector3.new(2, 3, 4))).toBe(24)
	end)

	it("is zero when any component is zero", function()
		expect(Vector3Utils.volume(Vector3.new(0, 3, 4))).toBe(0)
		expect(Vector3Utils.volume(Vector3.zero)).toBe(0)
	end)

	it("handles fractional components", function()
		expect(Vector3Utils.volume(Vector3.new(0.5, 0.5, 0.5))).toBeCloseTo(0.125, 5)
	end)
end)

describe("Vector3Utils.fromVector2XY", function()
	it("places the vector in the XY plane", function()
		expect(Vector3Utils.fromVector2XY(Vector2.new(3, 4))).toEqual(Vector3.new(3, 4, 0))
	end)
end)

describe("Vector3Utils.fromVector2XZ", function()
	it("places the vector in the XZ plane", function()
		expect(Vector3Utils.fromVector2XZ(Vector2.new(3, 4))).toEqual(Vector3.new(3, 0, 4))
	end)
end)

describe("Vector3Utils.getAngleRad", function()
	it("returns the angle between unit vectors", function()
		expect(Vector3Utils.getAngleRad(Vector3.xAxis, Vector3.yAxis)).toBeCloseTo(math.pi / 2, 5)
		expect(Vector3Utils.getAngleRad(Vector3.xAxis, Vector3.xAxis)).toBeCloseTo(0, 5)
		expect(Vector3Utils.getAngleRad(Vector3.xAxis, -Vector3.xAxis)).toBeCloseTo(math.pi, 5)
	end)

	it("returns nil for a zero vector", function()
		expect(Vector3Utils.getAngleRad(Vector3.zero, Vector3.xAxis)).toBeNil()
	end)
end)

describe("Vector3Utils.reflect", function()
	it("flips the component along the normal", function()
		local reflected = Vector3Utils.reflect(Vector3.new(1, -1, 0), Vector3.yAxis)
		expectVector3Close(reflected, Vector3.new(1, 1, 0))
	end)

	it("leaves a vector parallel to the surface unchanged", function()
		local reflected = Vector3Utils.reflect(Vector3.new(1, 0, 2), Vector3.yAxis)
		expectVector3Close(reflected, Vector3.new(1, 0, 2))
	end)
end)

describe("Vector3Utils.angleBetweenVectors", function()
	it("returns the angle for non-unit vectors", function()
		expect(Vector3Utils.angleBetweenVectors(Vector3.new(5, 0, 0), Vector3.new(0, 2, 0))).toBeCloseTo(math.pi / 2, 5)
	end)

	it("returns zero for parallel vectors", function()
		expect(Vector3Utils.angleBetweenVectors(Vector3.new(1, 1, 0), Vector3.new(3, 3, 0))).toBeCloseTo(0, 5)
	end)

	it("returns pi for opposite vectors", function()
		expect(Vector3Utils.angleBetweenVectors(Vector3.xAxis, -Vector3.xAxis)).toBeCloseTo(math.pi, 5)
	end)
end)

describe("Vector3Utils.slerp", function()
	it("returns the start at t=0", function()
		expectVector3Close(Vector3Utils.slerp(Vector3.xAxis, Vector3.yAxis, 0), Vector3.xAxis)
	end)

	it("returns the finish at t=1", function()
		expectVector3Close(Vector3Utils.slerp(Vector3.xAxis, Vector3.yAxis, 1), Vector3.yAxis)
	end)

	it("returns the midpoint on the arc at t=0.5", function()
		local halfway = Vector3Utils.slerp(Vector3.xAxis, Vector3.yAxis, 0.5)
		expectVector3Close(halfway, Vector3.new(math.sqrt(0.5), math.sqrt(0.5), 0))
		expect(halfway.Magnitude).toBeCloseTo(1, 5)
	end)
end)

describe("Vector3Utils.constrainToCone", function()
	it("returns the direction unchanged when inside the cone", function()
		local direction = Vector3.new(1, 0.1, 0)
		local constrained = Vector3Utils.constrainToCone(direction, Vector3.xAxis, math.rad(90))
		expect(constrained).toBe(direction)
	end)

	it("clamps the direction to the cone edge and preserves magnitude", function()
		local direction = Vector3.new(0, 3, 0)
		local constrained = Vector3Utils.constrainToCone(direction, Vector3.xAxis, math.rad(90))

		expect(constrained.Magnitude).toBeCloseTo(3, 5)
		expect(Vector3Utils.angleBetweenVectors(constrained, Vector3.xAxis)).toBeCloseTo(math.rad(45), 5)
		expectVector3Close(constrained, Vector3.new(3 * math.sqrt(0.5), 3 * math.sqrt(0.5), 0))
	end)
end)

describe("Vector3Utils.round", function()
	it("rounds each component to the nearest multiple", function()
		expect(Vector3Utils.round(Vector3.new(1.4, 2.6, -0.4), 1)).toEqual(Vector3.new(1, 3, 0))
		expect(Vector3Utils.round(Vector3.new(5, 6, 7), 4)).toEqual(Vector3.new(4, 8, 8))
	end)
end)

describe("Vector3Utils.areClose", function()
	it("is true when every component is within epsilon", function()
		expect(Vector3Utils.areClose(Vector3.new(1, 2, 3), Vector3.new(1.001, 1.999, 3), 0.01)).toBe(true)
	end)

	it("is false when any component exceeds epsilon", function()
		expect(Vector3Utils.areClose(Vector3.new(1, 2, 3), Vector3.new(1, 2, 3.1), 0.01)).toBe(false)
	end)

	it("treats epsilon as inclusive", function()
		expect(Vector3Utils.areClose(Vector3.zero, Vector3.new(EPSILON, 0, 0), EPSILON)).toBe(true)
	end)

	it("errors on a non-number epsilon", function()
		expect(function()
			Vector3Utils.areClose(Vector3.zero, Vector3.zero, nil :: any)
		end).toThrow()
	end)
end)
