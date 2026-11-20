--!strict
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local LinearValue = require("LinearValue")
local Spring = require("Spring")
local SpringUtils = require("SpringUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type ManualClock = {
	now: number,
	clock: () -> number,
}

local function createClock(): ManualClock
	local manual = {} :: ManualClock
	manual.now = 0
	manual.clock = function()
		return manual.now
	end
	return manual
end

describe("SpringUtils.animating", function()
	it("is not animating at rest and returns the target", function()
		local spring = Spring.new(5, createClock().clock)

		local animating, value = SpringUtils.animating(spring)

		expect(animating).toBe(false)
		expect(value).toBe(5)
	end)

	it("is animating while moving and returns the position", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring.Target = 1
		manual.now = 1

		local animating, value = SpringUtils.animating(spring)

		expect(animating).toBe(true)
		expect(value).toBeCloseTo(1 - 2 * math.exp(-1), 10)
	end)

	it("is animating when on target but still moving", function()
		local spring = Spring.new(0, createClock().clock)
		spring:Impulse(1)

		local animating = SpringUtils.animating(spring)

		expect(animating).toBe(true)
	end)

	it("returns the exact target once settled", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring.Target = 1
		manual.now = 100

		local animating, value = SpringUtils.animating(spring)

		expect(animating).toBe(false)
		expect(value).toBe(1)
	end)

	it("respects a custom epsilon", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring.Target = 1
		manual.now = 10

		expect((SpringUtils.animating(spring))).toBe(true)
		expect((SpringUtils.animating(spring, 0.01))).toBe(false)
	end)

	it("supports Vector3", function()
		local manual = createClock()
		local spring = Spring.new(Vector3.zero, manual.clock)
		spring.Target = Vector3.new(1, 2, 3)

		expect((SpringUtils.animating(spring))).toBe(true)

		manual.now = 100
		local animating, value = SpringUtils.animating(spring)

		expect(animating).toBe(false)
		expect(value).toEqual(Vector3.new(1, 2, 3))
	end)

	it("supports Vector2", function()
		local manual = createClock()
		local spring = Spring.new(Vector2.zero, manual.clock)
		spring.Target = Vector2.new(1, 2)

		expect((SpringUtils.animating(spring))).toBe(true)

		manual.now = 100

		expect((SpringUtils.animating(spring))).toBe(false)
	end)

	it("supports LinearValue", function()
		local manual = createClock()
		local spring = Spring.new(SpringUtils.toLinearIfNeeded(Color3.new(0, 0, 0)) :: any, manual.clock)
		spring.Target = SpringUtils.toLinearIfNeeded(Color3.new(1, 0.5, 0.25))

		expect((SpringUtils.animating(spring))).toBe(true)

		manual.now = 100
		local animating, value = SpringUtils.animating(spring)

		expect(animating).toBe(false)
		expect(SpringUtils.fromLinearIfNeeded(value)).toEqual(Color3.new(1, 0.5, 0.25))
	end)
end)

describe("SpringUtils.getVelocityAdjustment", function()
	it("scales velocity by twice the damper over the speed", function()
		expect(SpringUtils.getVelocityAdjustment(10, 1, 4)).toBe(5)
	end)

	it("supports Vector3", function()
		expect(SpringUtils.getVelocityAdjustment(Vector3.new(2, 4, 6), 0.5, 2)).toEqual(Vector3.new(1, 2, 3))
	end)
end)

describe("SpringUtils linear conversion", function()
	it("round trips values Roblox cannot do arithmetic on", function()
		local color = Color3.new(0.25, 0.5, 0.75)
		local linear = SpringUtils.toLinearIfNeeded(color)

		expect(LinearValue.isLinear(linear)).toBe(true)
		expect(SpringUtils.fromLinearIfNeeded(linear)).toEqual(color)
	end)

	it("passes through values that already support arithmetic", function()
		expect(SpringUtils.toLinearIfNeeded(5)).toBe(5)
		expect(SpringUtils.fromLinearIfNeeded(5)).toBe(5)
	end)
end)
