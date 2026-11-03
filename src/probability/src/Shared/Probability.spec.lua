--!strict
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local Probability = require("Probability")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local SAMPLE_COUNT = 100000

local function measure(sample: () -> number): (number, number)
	local sum = 0
	local sumSquares = 0
	for _ = 1, SAMPLE_COUNT do
		local value = sample()
		sum += value
		sumSquares += value * value
	end

	local mean = sum / SAMPLE_COUNT
	local variance = sumSquares / SAMPLE_COUNT - mean * mean
	return mean, math.sqrt(variance)
end

describe("Probability.boxMuller", function()
	it("samples a standard normal distribution", function()
		local mean, standardDeviation = measure(Probability.boxMuller)

		expect(math.abs(mean) < 0.02).toBe(true)
		expect(math.abs(standardDeviation - 1) < 0.02).toBe(true)
	end)

	it("maps uniform inputs through the Box-Muller transform", function()
		local value = Probability._boxMullerFromUniform(1 - math.exp(-0.5), 0.5)

		expect(value).toBeCloseTo(-1, 10)
	end)

	it("stays finite when math.random returns 0", function()
		local value = Probability._boxMullerFromUniform(0, 0)

		expect(math.abs(value)).toBe(0)
	end)

	it("stays finite at the top of the math.random range", function()
		local value = Probability._boxMullerFromUniform(1 - 2 ^ -53, 0)

		expect(value == value and math.abs(value) < math.huge).toBe(true)
	end)
end)

describe("Probability.normal", function()
	it("honors the requested mean and standard deviation", function()
		local mean, standardDeviation = measure(function()
			return Probability.normal(10, 3)
		end)

		expect(math.abs(mean - 10) < 0.06).toBe(true)
		expect(math.abs(standardDeviation - 3) < 0.06).toBe(true)
	end)
end)
