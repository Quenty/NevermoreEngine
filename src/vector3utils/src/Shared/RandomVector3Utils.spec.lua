--!strict
--[[
	@class RandomVector3Utils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local RandomVector3Utils = require("RandomVector3Utils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local SAMPLE_COUNT = 500
local UNIT_TOLERANCE = 1e-4

local function sample(count: number, generate: () -> Vector3): { Vector3 }
	local samples = table.create(count)
	for i = 1, count do
		samples[i] = generate()
	end
	return samples
end

local function expectAllUnit(samples: { Vector3 })
	for _, vector in samples do
		expect(math.abs(vector.Magnitude - 1)).toBeLessThan(UNIT_TOLERANCE)
	end
end

local function coversBothSigns(samples: { Vector3 }, axis: Vector3): boolean
	local sawNegative, sawPositive = false, false
	for _, vector in samples do
		local component = vector:Dot(axis)
		if component < 0 then
			sawNegative = true
		elseif component > 0 then
			sawPositive = true
		end
	end
	return sawNegative and sawPositive
end

local function mean(samples: { Vector3 }): Vector3
	local total = Vector3.zero
	for _, vector in samples do
		total += vector
	end
	return total / #samples
end

describe("RandomVector3Utils.getRandomUnitVector", function()
	it("returns unit vectors", function()
		expectAllUnit(sample(SAMPLE_COUNT, RandomVector3Utils.getRandomUnitVector))
	end)

	it("covers every axis in both directions", function()
		local samples = sample(SAMPLE_COUNT, RandomVector3Utils.getRandomUnitVector)

		expect(coversBothSigns(samples, Vector3.xAxis)).toBe(true)
		expect(coversBothSigns(samples, Vector3.yAxis)).toBe(true)
		expect(coversBothSigns(samples, Vector3.zAxis)).toBe(true)
	end)
end)

describe("RandomVector3Utils.gaussianRandom", function()
	it("returns the mean when the spread is zero", function()
		local center = Vector3.new(1, -2, 3)

		expect(RandomVector3Utils.gaussianRandom(center, Vector3.zero)).toEqual(center)
	end)

	it("only varies along axes with spread", function()
		local samples = sample(SAMPLE_COUNT, function()
			return RandomVector3Utils.gaussianRandom(Vector3.zero, Vector3.yAxis)
		end)

		for _, vector in samples do
			expect(vector.X).toBe(0)
			expect(vector.Z).toBe(0)
		end
		expect(coversBothSigns(samples, Vector3.yAxis)).toBe(true)
	end)

	it("clusters around the mean", function()
		local center = Vector3.new(10, 20, 30)
		local samples = sample(4000, function()
			return RandomVector3Utils.gaussianRandom(center, Vector3.one)
		end)

		local average = mean(samples)
		expect(math.abs(average.X - center.X)).toBeLessThan(0.15)
		expect(math.abs(average.Y - center.Y)).toBeLessThan(0.15)
		expect(math.abs(average.Z - center.Z)).toBeLessThan(0.15)
	end)
end)

describe("RandomVector3Utils.getDirectedRandomUnitVector", function()
	local DIRECTIONS = {
		Vector3.xAxis,
		-Vector3.xAxis,
		Vector3.yAxis,
		-Vector3.zAxis,
		Vector3.new(3, -4, 12),
	}

	it("returns the direction itself when the angle is zero", function()
		for _, direction in DIRECTIONS do
			local result = RandomVector3Utils.getDirectedRandomUnitVector(direction, 0)

			expect(math.abs(result:Dot(direction.Unit) - 1)).toBeLessThan(UNIT_TOLERANCE)
		end
	end)

	it("returns unit vectors within the cone for every direction", function()
		local angleRad = math.rad(30)
		local minDot = math.cos(angleRad) - UNIT_TOLERANCE

		for _, direction in DIRECTIONS do
			local samples = sample(SAMPLE_COUNT, function()
				return RandomVector3Utils.getDirectedRandomUnitVector(direction, angleRad)
			end)

			expectAllUnit(samples)
			for _, vector in samples do
				expect(vector:Dot(direction.Unit)).toBeGreaterThanOrEqual(minDot)
			end
		end
	end)

	it("spreads out to the cone edge", function()
		local angleRad = math.rad(60)
		local samples = sample(SAMPLE_COUNT, function()
			return RandomVector3Utils.getDirectedRandomUnitVector(Vector3.yAxis, angleRad)
		end)

		local widestDot = 1
		for _, vector in samples do
			widestDot = math.min(widestDot, vector:Dot(Vector3.yAxis))
		end

		expect(widestDot).toBeLessThan(math.cos(math.rad(50)))
	end)

	it("covers the full sphere at a half turn", function()
		local samples = sample(SAMPLE_COUNT, function()
			return RandomVector3Utils.getDirectedRandomUnitVector(Vector3.xAxis, math.pi)
		end)

		expectAllUnit(samples)
		expect(coversBothSigns(samples, Vector3.xAxis)).toBe(true)
		expect(coversBothSigns(samples, Vector3.yAxis)).toBe(true)
		expect(coversBothSigns(samples, Vector3.zAxis)).toBe(true)
	end)

	it("errors on bad arguments", function()
		expect(function()
			RandomVector3Utils.getDirectedRandomUnitVector("up" :: any, 1)
		end).toThrow("Bad direction")

		expect(function()
			RandomVector3Utils.getDirectedRandomUnitVector(Vector3.xAxis, "wide" :: any)
		end).toThrow("Bad angleRad")
	end)
end)
