--!strict
--[[
	@class TimedTween.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Jest = require("Jest")
local TimedTween = require("TimedTween")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local TRANSITION_TIME = 0.1

type Controller = {
	tween: TimedTween.TimedTween,
	position: () -> number,
	rtime: () -> number,
	remainingTime: () -> number,
	setClock: (clock: () -> number) -> (),
	advance: (seconds: number) -> (),
	destroy: () -> (),
}

local function setup(): Controller
	local tween: any = TimedTween.new(TRANSITION_TIME)

	local now = 0
	tween:SetClock(function()
		return now
	end)

	return {
		tween = tween,
		position = function()
			return tween:_computeState(tween:GetClock()()).p
		end,
		rtime = function()
			return tween:_computeState(tween:GetClock()()).rtime
		end,
		remainingTime = function()
			return tween._state.Value.t1 - tween:GetClock()()
		end,
		setClock = function(clock: () -> number)
			tween:SetClock(clock)
		end,
		advance = function(seconds: number)
			now += seconds
		end,
		destroy = function()
			tween:Destroy()
		end,
	}
end

describe("TimedTween.GetClock", function()
	it("defaults to os.clock", function()
		local tween = TimedTween.new()

		expect(tween:GetClock()).toBe(os.clock)

		tween:Destroy()
	end)

	it("returns the clock that was set", function()
		local controller = setup()
		local clock = function()
			return 100
		end

		controller.setClock(clock)

		expect(controller.tween:GetClock()).toBe(clock)

		controller.destroy()
	end)
end)

describe("TimedTween:SetClock", function()
	it("rejects a clock that is not a function", function()
		local controller = setup()

		expect(function()
			controller.tween:SetClock(5 :: any)
		end).toThrow("Bad clock")

		controller.destroy()
	end)

	it("holds position when swapped while settled", function()
		local controller = setup()

		controller.tween:Show(true)
		expect(controller.position()).toBe(1)

		controller.setClock(function()
			return 5000
		end)

		expect(controller.position()).toBe(1)

		controller.destroy()
	end)

	it("holds position when swapped mid-tween", function()
		local controller = setup()

		controller.tween:Show()
		controller.advance(TRANSITION_TIME / 4)
		expect(controller.position()).toBeCloseTo(0.25)

		controller.setClock(function()
			return 5000
		end)

		expect(controller.position()).toBeCloseTo(0.25)

		controller.destroy()
	end)

	it("holds the time left when swapped mid-tween", function()
		local controller = setup()

		controller.tween:Show()
		controller.advance(TRANSITION_TIME / 4)
		local before = controller.remainingTime()

		controller.setClock(function()
			return 5000
		end)

		expect(controller.remainingTime()).toBeCloseTo(before)
		expect(controller.remainingTime()).toBeCloseTo(TRANSITION_TIME * 0.75)

		controller.destroy()
	end)

	it("keeps animating on the new clock from where it left off", function()
		local controller = setup()

		controller.tween:Show()
		controller.advance(TRANSITION_TIME / 2)
		expect(controller.position()).toBeCloseTo(0.5)

		local now = 5000
		controller.setClock(function()
			return now
		end)

		now += TRANSITION_TIME / 4
		expect(controller.position()).toBeCloseTo(0.75)

		now += TRANSITION_TIME
		expect(controller.position()).toBe(1)

		controller.destroy()
	end)

	it("does not restart a tween that was swapped mid-flight", function()
		local controller = setup()

		controller.tween:Show()
		controller.advance(TRANSITION_TIME / 2)

		controller.setClock(function()
			return 5000
		end)

		-- A restart would put the position back to 0 and the time left back to the full duration
		expect(controller.position()).never.toBe(0)
		expect(controller.remainingTime()).never.toBeCloseTo(TRANSITION_TIME)

		controller.destroy()
	end)

	it("survives being swapped backwards onto an earlier timebase", function()
		local controller = setup()

		controller.advance(1000)
		controller.tween:Show()
		controller.advance(TRANSITION_TIME / 2)
		expect(controller.position()).toBeCloseTo(0.5)

		controller.setClock(function()
			return 0
		end)

		expect(controller.position()).toBeCloseTo(0.5)

		controller.destroy()
	end)
end)

describe("TimedTween position", function()
	it("starts at zero and hidden", function()
		local controller = setup()

		expect(controller.tween:IsVisible()).toBe(false)
		expect(controller.position()).toBe(0)

		controller.destroy()
	end)

	it("moves linearly across the transition time", function()
		local controller = setup()

		controller.tween:Show()

		controller.advance(TRANSITION_TIME / 4)
		expect(controller.position()).toBeCloseTo(0.25)

		controller.advance(TRANSITION_TIME / 4)
		expect(controller.position()).toBeCloseTo(0.5)

		controller.advance(TRANSITION_TIME)
		expect(controller.position()).toBe(1)

		controller.destroy()
	end)

	it("snaps when told not to animate", function()
		local controller = setup()

		controller.tween:Show(true)
		expect(controller.position()).toBe(1)

		controller.tween:Hide(true)
		expect(controller.position()).toBe(0)

		controller.destroy()
	end)

	it("reverses from wherever it currently is", function()
		local controller = setup()

		controller.tween:Show()
		controller.advance(TRANSITION_TIME / 2)
		expect(controller.position()).toBeCloseTo(0.5)

		controller.tween:Hide()
		controller.advance(TRANSITION_TIME)

		expect(controller.position()).toBe(0)

		controller.destroy()
	end)
end)

describe("TimedTween remaining time", function()
	it("reports the full transition time at the start of a show", function()
		local controller = setup()

		controller.tween:Show()

		expect(controller.rtime()).toBeCloseTo(TRANSITION_TIME)

		controller.destroy()
	end)

	it("counts down with the clock", function()
		local controller = setup()

		controller.tween:Show()
		controller.advance(TRANSITION_TIME / 4)

		expect(controller.rtime()).toBeCloseTo(TRANSITION_TIME * 0.75)

		controller.destroy()
	end)

	it("reports the time left, not the distance left, when reversing mid-tween", function()
		local controller = setup()

		controller.tween:Show()
		controller.advance(TRANSITION_TIME / 2)

		-- Covering half the range takes half the transition time, and that scaling already lives
		-- in the duration -- folding the remaining distance in again would report half of this.
		controller.tween:Hide()

		expect(controller.rtime()).toBeCloseTo(TRANSITION_TIME / 2)
		expect(controller.rtime()).toBeCloseTo(controller.remainingTime())

		controller.destroy()
	end)

	it("stays consistent partway through a reversed tween", function()
		local controller = setup()

		controller.tween:Show()
		controller.advance(TRANSITION_TIME / 2)
		controller.tween:Hide()
		controller.advance(TRANSITION_TIME / 4)

		expect(controller.rtime()).toBeCloseTo(TRANSITION_TIME / 4)

		controller.destroy()
	end)

	it("reports zero once settled", function()
		local controller = setup()

		controller.tween:Show()
		controller.advance(TRANSITION_TIME * 2)

		expect(controller.rtime()).toBe(0)

		controller.destroy()
	end)

	it("reports zero when told not to animate", function()
		local controller = setup()

		controller.tween:Show(true)

		expect(controller.rtime()).toBe(0)

		controller.destroy()
	end)
end)

describe("TimedTween:SetVisible", function()
	it("snaps an already-running show when told not to animate", function()
		local controller = setup()

		controller.tween:Show()
		controller.advance(TRANSITION_TIME / 2)
		expect(controller.position()).toBeCloseTo(0.5)

		controller.tween:Show(true)

		expect(controller.position()).toBe(1)
		expect(controller.rtime()).toBe(0)

		controller.destroy()
	end)

	it("snaps an already-running hide when told not to animate", function()
		local controller = setup()

		controller.tween:Show(true)
		controller.tween:Hide()
		controller.advance(TRANSITION_TIME / 2)

		controller.tween:Hide(true)

		expect(controller.position()).toBe(0)
		expect(controller.rtime()).toBe(0)

		controller.destroy()
	end)

	it("leaves a settled tween alone", function()
		local controller = setup()

		controller.tween:Show(true)
		controller.tween:Show(true)

		expect(controller.position()).toBe(1)
		expect(controller.tween:IsVisible()).toBe(true)

		controller.destroy()
	end)

	it("rejects a visibility that is not a boolean", function()
		local controller = setup()

		expect(function()
			controller.tween:SetVisible(5 :: any)
		end).toThrow()

		controller.destroy()
	end)
end)

describe("TimedTween:PromiseFinished", function()
	it("resolves immediately when there is nothing left to run", function()
		local controller = setup()

		expect(controller.tween:PromiseFinished():IsFulfilled()).toBe(true)

		controller.destroy()
	end)

	it("waits on the injected clock rather than wall time", function()
		local controller = setup()

		controller.tween:Show()
		local promise = controller.tween:PromiseFinished()
		expect(promise:IsPending()).toBe(true)

		-- Wall time runs well past the transition while the injected clock stays put
		task.wait(TRANSITION_TIME * 3)
		expect(promise:IsPending()).toBe(true)

		controller.advance(TRANSITION_TIME * 2)
		task.wait()
		task.wait()

		expect(promise:IsFulfilled()).toBe(true)

		controller.destroy()
	end)

	it("waits on wall time under the default clock", function()
		local tween = TimedTween.new(TRANSITION_TIME)

		tween:Show()
		local promise = tween:PromiseFinished()
		expect(promise:IsPending()).toBe(true)

		task.wait(TRANSITION_TIME * 3)

		expect(promise:IsFulfilled()).toBe(true)

		tween:Destroy()
	end)
end)

describe("TimedTween:SetTransitionTime", function()
	it("changes the transition time", function()
		local controller = setup()

		controller.tween:SetTransitionTime(0.5)

		expect(controller.tween:GetTransitionTime()).toBe(0.5)

		controller.destroy()
	end)

	it("defaults to 0.15 seconds", function()
		local tween = TimedTween.new()

		expect(tween:GetTransitionTime()).toBe(0.15)

		tween:Destroy()
	end)
end)
