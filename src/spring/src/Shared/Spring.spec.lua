--!strict
local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local LinearValue = require("LinearValue")
local Spring = require("Spring")

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

describe("Spring.new", function()
	it("starts at rest on the initial value", function()
		local manual = createClock()
		local spring = Spring.new(5, manual.clock)

		expect(spring.Position).toBe(5)
		expect(spring.Velocity).toBe(0)
		expect(spring.Target).toBe(5)
		expect(spring.Damper).toBe(1)
		expect(spring.Speed).toBe(1)
		expect(spring.Clock).toBe(manual.clock)
	end)

	it("defaults to zero", function()
		local spring = Spring.new()

		expect(spring.Position).toBe(0)
		expect(spring.Target).toBe(0)
	end)

	it("stays at rest while time passes", function()
		local manual = createClock()
		local spring = Spring.new(5, manual.clock)

		manual.now = 10

		expect(spring.Position).toBe(5)
		expect(spring.Velocity).toBe(0)
	end)

	it("supports Vector3", function()
		local manual = createClock()
		local spring = Spring.new(Vector3.zero, manual.clock)

		spring.Target = Vector3.new(1, 2, 3)
		manual.now = 100

		expect(spring.Position.X).toBeCloseTo(1, 5)
		expect(spring.Position.Y).toBeCloseTo(2, 5)
		expect(spring.Position.Z).toBeCloseTo(3, 5)
	end)
end)

describe("Spring motion", function()
	it("follows the critically damped solution", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)

		spring.Target = 1
		manual.now = 1

		expect(spring.Position).toBeCloseTo(1 - 2 * math.exp(-1), 10)
		expect(spring.Velocity).toBeCloseTo(math.exp(-1), 10)
	end)

	it("settles on the target", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)

		spring.Target = 1
		manual.now = 100

		expect(spring.Position).toBeCloseTo(1, 10)
		expect(spring.Velocity).toBeCloseTo(0, 10)
	end)

	it("overshoots when underdamped", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring.Damper = 0

		spring.Target = 1
		manual.now = math.pi

		expect(spring.Position).toBeCloseTo(2, 10)
	end)

	it("never overshoots when overdamped", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring.Damper = 2

		spring.Target = 1

		local previous = spring.Position
		for step = 1, 50 do
			manual.now = step * 0.2
			local position = spring.Position
			expect(position >= previous).toBe(true)
			expect(position <= 1).toBe(true)
			previous = position
		end
	end)

	it("scales time by speed", function()
		local slowClock = createClock()
		local slow = Spring.new(0, slowClock.clock)
		slow.Target = 1
		slowClock.now = 1

		local fastClock = createClock()
		local fast = Spring.new(0, fastClock.clock)
		fast.Speed = 2
		fast.Target = 1
		fastClock.now = 0.5

		expect(fast.Position).toBeCloseTo(slow.Position, 10)
	end)

	it("keeps position and velocity when the damper changes mid flight", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring.Target = 1
		manual.now = 1

		local position = spring.Position
		local velocity = spring.Velocity
		spring.Damper = 0.5

		expect(spring.Position).toBeCloseTo(position, 10)
		expect(spring.Velocity).toBeCloseTo(velocity, 10)
	end)

	it("clamps negative speed to zero", function()
		local spring = Spring.new(0, createClock().clock)

		spring.Speed = -1

		expect(spring.Speed).toBe(0)
	end)
end)

describe("Spring setters", function()
	it("keeps velocity when the position is set", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring.Target = 1
		manual.now = 1

		local velocity = spring.Velocity
		spring.Position = 0.5

		expect(spring.Position).toBe(0.5)
		expect(spring.Velocity).toBeCloseTo(velocity, 10)
	end)

	it("keeps position when the velocity is set", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring.Target = 1
		manual.now = 1

		local position = spring.Position
		spring.Velocity = 3

		expect(spring.Position).toBeCloseTo(position, 10)
		expect(spring.Velocity).toBe(3)
	end)

	it("supports short aliases", function()
		local spring = Spring.new(0, createClock().clock)

		spring.p = 1
		spring.v = 2
		spring.t = 3
		spring.d = 0.5
		spring.s = 4

		expect(spring.p).toBe(1)
		expect(spring.v).toBe(2)
		expect(spring.t).toBe(3)
		expect(spring.d).toBe(0.5)
		expect(spring.s).toBe(4)
		expect(spring.Value).toBe(1)
	end)

	it("errors on unknown members", function()
		local spring = Spring.new(0, createClock().clock) :: any

		expect(function()
			return spring.Nonsense
		end).toThrow('"Nonsense" is not a valid member of Spring')
		expect(function()
			spring.Nonsense = 1
		end).toThrow('"Nonsense" is not a valid member of Spring')
	end)

	it("keeps position when the clock is swapped", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring.Target = 1
		manual.now = 1

		local position = spring.Position
		local other = createClock()
		other.now = 500
		spring.Clock = other.clock

		expect(spring.Position).toBeCloseTo(position, 10)
		expect(spring.Clock).toBe(other.clock)
	end)
end)

describe("Spring.Impulse", function()
	it("adds to the current velocity", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)

		spring:Impulse(1)
		spring:Impulse(2)

		expect(spring.Velocity).toBe(3)
	end)

	it("moves the spring away from rest", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)

		spring:Impulse(1)
		manual.now = 1

		expect(spring.Position).toBeCloseTo(math.exp(-1), 10)
	end)
end)

describe("Spring.TimeSkip", function()
	it("advances the spring without the clock moving", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring.Target = 1

		spring:TimeSkip(1)

		expect(spring.Position).toBeCloseTo(1 - 2 * math.exp(-1), 10)
		expect(spring.Velocity).toBeCloseTo(math.exp(-1), 10)
	end)
end)

describe("Spring.SetTarget", function()
	it("animates towards the target by default", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)

		spring:SetTarget(1)

		expect(spring.Target).toBe(1)
		expect(spring.Position).toBe(0)
	end)

	it("snaps to the target when not animating", function()
		local manual = createClock()
		local spring = Spring.new(0, manual.clock)
		spring:Impulse(5)

		spring:SetTarget(1, true)

		expect(spring.Target).toBe(1)
		expect(spring.Position).toBe(1)
		expect(spring.Velocity).toBe(0)
	end)
end)

describe("Spring with LinearValue", function()
	it("animates a Color3 to its target", function()
		local manual = createClock()
		local spring = Spring.new(LinearValue.toLinearIfNeeded(Color3.new(0, 0, 0)) :: any, manual.clock)

		spring.Target = LinearValue.toLinearIfNeeded(Color3.new(1, 0.5, 0.25))
		manual.now = 100

		local color = LinearValue.fromLinearIfNeeded(spring.Position)
		expect(color.R).toBeCloseTo(1, 5)
		expect(color.G).toBeCloseTo(0.5, 5)
		expect(color.B).toBeCloseTo(0.25, 5)
	end)
end)
