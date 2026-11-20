--!strict
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local LinearValue = require("LinearValue")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function toLinear(value: any): any
	return LinearValue.toLinearIfNeeded(value)
end

describe("LinearValue.toLinearIfNeeded", function()
	it("round trips Color3", function()
		local color = Color3.new(0.25, 0.5, 0.75)

		expect(LinearValue.fromLinearIfNeeded(toLinear(color))).toEqual(color)
	end)

	it("round trips UDim2", function()
		local udim2 = UDim2.new(0.5, 10, 0.25, -20)

		expect(LinearValue.fromLinearIfNeeded(toLinear(udim2))).toEqual(udim2)
	end)

	it("round trips UDim", function()
		local udim = UDim.new(0.5, 10)

		expect(LinearValue.fromLinearIfNeeded(toLinear(udim))).toEqual(udim)
	end)

	it("round trips booleans", function()
		expect(LinearValue.fromLinearIfNeeded(toLinear(true))).toBe(true)
		expect(LinearValue.fromLinearIfNeeded(toLinear(false))).toBe(false)
	end)

	it("round trips Rect", function()
		local rect = Rect.new(1, 2, 3, 4)

		expect(LinearValue.fromLinearIfNeeded(toLinear(rect))).toEqual(rect)
	end)

	it("wraps types Roblox cannot do arithmetic on", function()
		expect(LinearValue.isLinear(toLinear(Color3.new()))).toBe(true)
		expect(LinearValue.isLinear(toLinear(UDim2.new()))).toBe(true)
		expect(LinearValue.isLinear(toLinear(UDim.new()))).toBe(true)
		expect(LinearValue.isLinear(toLinear(true))).toBe(true)
		expect(LinearValue.isLinear(toLinear(Rect.new(0, 0, 0, 0)))).toBe(true)
	end)

	it("passes through types that already support arithmetic", function()
		local vector = Vector3.new(1, 2, 3)

		expect(toLinear(5)).toBe(5)
		expect(toLinear(vector)).toEqual(vector)
	end)
end)

describe("LinearValue.fromLinearIfNeeded", function()
	it("passes through values that are not linear", function()
		expect(LinearValue.fromLinearIfNeeded(5)).toBe(5)
		expect(LinearValue.fromLinearIfNeeded("text")).toBe("text")
	end)
end)

describe("LinearValue.isLinear", function()
	it("rejects values that are not linear", function()
		expect(LinearValue.isLinear(5)).toBe(false)
		expect(LinearValue.isLinear({})).toBe(false)
		expect(LinearValue.isLinear(nil)).toBe(false)
	end)
end)

describe("LinearValue arithmetic", function()
	it("adds two linear values", function()
		local result = toLinear(UDim.new(0.25, 10)) + toLinear(UDim.new(0.5, 20))

		expect(result:ToBaseValue()).toEqual(UDim.new(0.75, 30))
	end)

	it("subtracts two linear values", function()
		local result = toLinear(UDim.new(0.75, 30)) - toLinear(UDim.new(0.5, 20))

		expect(result:ToBaseValue()).toEqual(UDim.new(0.25, 10))
	end)

	it("multiplies by a number on either side", function()
		local udim = toLinear(UDim.new(0.25, 10))

		expect((udim * 2):ToBaseValue()).toEqual(UDim.new(0.5, 20))
		expect((2 * udim):ToBaseValue()).toEqual(UDim.new(0.5, 20))
	end)

	it("divides by a number", function()
		local result = toLinear(UDim.new(0.5, 20)) / 2

		expect(result:ToBaseValue()).toEqual(UDim.new(0.25, 10))
	end)

	it("scales Color3 channels", function()
		local result = (toLinear(Color3.new(0.2, 0.4, 0.8)) * 0.5):ToBaseValue()

		expect(result.R).toBeCloseTo(0.1, 5)
		expect(result.G).toBeCloseTo(0.2, 5)
		expect(result.B).toBeCloseTo(0.4, 5)
	end)

	it("rounds UDim2 offsets to whole pixels", function()
		local result = (toLinear(UDim2.fromOffset(10, 10)) * 0.96):ToBaseValue()

		expect(result).toEqual(UDim2.fromOffset(10, 10))
	end)

	it("rounds UDim offsets to whole pixels", function()
		local result = (toLinear(UDim.new(0, 10)) * 0.96):ToBaseValue()

		expect(result).toEqual(UDim.new(0, 10))
	end)

	it("treats any nonzero value as true for booleans", function()
		expect((toLinear(true) * 0.01):ToBaseValue()).toBe(true)
		expect((toLinear(true) * 0):ToBaseValue()).toBe(false)
	end)

	it("errors when combining different kinds of linear value", function()
		expect(function()
			return toLinear(UDim.new()) + toLinear(Color3.new())
		end).toThrow("a is not the same type of linearValue as b")
	end)

	it("errors when combined with a value that is not a number", function()
		expect(function()
			return toLinear(UDim.new()) + "text"
		end).toThrow("Bad type (b)")
		expect(function()
			return "text" + toLinear(UDim.new())
		end).toThrow("Bad type (a)")
	end)
end)

describe("LinearValue.GetMagnitude", function()
	it("returns the euclidean length of the values", function()
		local linear = toLinear(UDim.new(3, 4))

		expect(linear:GetMagnitude()).toBe(5)
		expect(linear.magnitude).toBe(5)
		expect(linear.Magnitude).toBe(5)
	end)
end)

describe("LinearValue equality", function()
	it("equals another linear value with the same values", function()
		expect(toLinear(UDim.new(1, 2)) == toLinear(UDim.new(1, 2))).toBe(true)
	end)

	it("does not equal a linear value with different values", function()
		expect(toLinear(UDim.new(1, 2)) == toLinear(UDim.new(1, 3))).toBe(false)
	end)

	it("does not equal a linear value with a different number of values", function()
		expect(toLinear(UDim.new(1, 2)) == toLinear(Color3.new(1, 0.5, 0))).toBe(false)
	end)
end)
