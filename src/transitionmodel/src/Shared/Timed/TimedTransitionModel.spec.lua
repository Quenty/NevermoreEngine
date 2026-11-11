--!strict
--[[
	@class TimedTransitionModel.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local TimedTransitionModel = require("TimedTransitionModel")
local TransitionModel = require("TransitionModel")
local TransitionUtils = require("TransitionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local TRANSITION_TIME = 0.05

type Controller = {
	model: TimedTransitionModel.TimedTransitionModel,
	position: () -> number,
	advance: (seconds: number) -> (),
	Destroy: (self: Controller) -> (),
}

-- Completion runs off a real task.delay inside TimedTween.PromiseFinished, so the fake clock and
-- real time have to be advanced together.
local function setup(options: { transitionTime: number? }?): Controller
	local maid = Maid.new()

	local transitionTime = (options and options.transitionTime) or TRANSITION_TIME
	local model: any = maid:Add(TimedTransitionModel.new(transitionTime))

	local now = 0
	model._timedTween:SetClock(function()
		return now
	end)

	local controller: Controller = {
		model = model,
		position = function()
			return model._timedTween:_computeState(now).p
		end,
		advance = function(seconds: number)
			now += seconds
			task.wait(seconds)
			task.wait()
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("TimedTransitionModel.new", function()
	it("starts hidden with hiding already complete", function()
		local controller = setup()

		expect(controller.model:IsVisible()).toBe(false)
		expect(controller.model:IsShowingComplete()).toBe(false)
		expect(controller.model:IsHidingComplete()).toBe(true)
		expect(controller.position()).toBe(0)

		controller:Destroy()
	end)

	it("honors an explicit transition time", function()
		local controller = setup({ transitionTime = 0.5 })

		expect(controller.model._timedTween:GetTransitionTime()).toBe(0.5)

		controller:Destroy()
	end)

	it("is a basic pane", function()
		local controller = setup()

		expect(BasicPane.isBasicPane(controller.model)).toBe(true)

		controller:Destroy()
	end)
end)

describe("TimedTransitionModel visibility", function()
	it("starts the transition without arriving immediately", function()
		local controller = setup()

		controller.model:Show()

		expect(controller.model:IsVisible()).toBe(true)
		expect(controller.model:IsShowingComplete()).toBe(false)
		expect(controller.model:IsHidingComplete()).toBe(false)
		expect(controller.position()).toBe(0)

		controller:Destroy()
	end)

	it("moves halfway through the transition time", function()
		local controller = setup()

		controller.model:Show()
		controller.advance(TRANSITION_TIME / 2)

		expect(controller.position()).toBeCloseTo(0.5)

		controller:Destroy()
	end)

	it("completes showing once the transition time elapses", function()
		local controller = setup()

		controller.model:Show()
		controller.advance(TRANSITION_TIME * 2)

		expect(controller.model:IsShowingComplete()).toBe(true)
		expect(controller.position()).toBe(1)

		controller:Destroy()
	end)

	it("completes hiding once the transition time elapses", function()
		local controller = setup()

		controller.model:Show(true)
		controller.model:Hide()
		controller.advance(TRANSITION_TIME * 2)

		expect(controller.model:IsHidingComplete()).toBe(true)
		expect(controller.position()).toBe(0)

		controller:Destroy()
	end)

	it("completes immediately when told not to animate", function()
		local controller = setup()

		controller.model:Show(true)

		expect(controller.model:IsShowingComplete()).toBe(true)
		expect(controller.position()).toBe(1)

		controller:Destroy()
	end)

	it("toggles visibility", function()
		local controller = setup()

		controller.model:Toggle(true)
		expect(controller.model:IsVisible()).toBe(true)

		controller.model:Toggle(true)
		expect(controller.model:IsVisible()).toBe(false)

		controller:Destroy()
	end)
end)

describe("TimedTransitionModel:SetTransitionTime", function()
	it("changes how long the transition takes", function()
		local controller = setup()

		controller.model:SetTransitionTime(0.5)

		expect(controller.model._timedTween:GetTransitionTime()).toBe(0.5)

		controller:Destroy()
	end)
end)

describe("TimedTransitionModel promises", function()
	it("promises the show until the transition finishes", function()
		local controller = setup()

		local promise = controller.model:PromiseShow()
		expect(promise:IsPending()).toBe(true)

		controller.advance(TRANSITION_TIME * 2)

		expect(promise:IsFulfilled()).toBe(true)

		controller:Destroy()
	end)

	it("promises the hide until the transition finishes", function()
		local controller = setup()

		controller.model:Show(true)

		local promise = controller.model:PromiseHide()
		expect(promise:IsPending()).toBe(true)

		controller.advance(TRANSITION_TIME * 2)

		expect(promise:IsFulfilled()).toBe(true)

		controller:Destroy()
	end)

	it("resolves without waiting when told not to animate", function()
		local controller = setup()

		expect(controller.model:PromiseShow(true):IsFulfilled()).toBe(true)

		controller:Destroy()
	end)

	it("promises the toggle in whichever direction it goes", function()
		local controller = setup()

		expect(controller.model:PromiseToggle(true):IsFulfilled()).toBe(true)
		expect(controller.model:IsVisible()).toBe(true)

		expect(controller.model:PromiseToggle(true):IsFulfilled()).toBe(true)
		expect(controller.model:IsVisible()).toBe(false)

		controller:Destroy()
	end)

	it("reports completion through ObserveIsShowingComplete", function()
		local controller = setup()
		local values = {}
		local sub = controller.model:ObserveIsShowingComplete():Subscribe(function(value)
			table.insert(values, value)
		end)

		controller.model:Show()
		controller.advance(TRANSITION_TIME * 2)

		expect(values).toEqual({ false, true })

		sub:Destroy()
		controller:Destroy()
	end)
end)

describe("TimedTransitionModel completion signals", function()
	it("fires ShowingComplete once the transition finishes", function()
		local controller = setup()
		local fires = 0
		controller.model.ShowingComplete:Connect(function()
			fires += 1
		end)

		controller.model:Show()
		expect(fires).toBe(0)

		controller.advance(TRANSITION_TIME * 2)
		expect(fires).toBe(1)

		controller:Destroy()
	end)

	it("fires HidingComplete once the transition finishes", function()
		local controller = setup()
		local fires = 0
		controller.model.HidingComplete:Connect(function()
			fires += 1
		end)

		controller.model:Show(true)
		controller.model:Hide()
		expect(fires).toBe(0)

		controller.advance(TRANSITION_TIME * 2)
		expect(fires).toBe(1)

		controller:Destroy()
	end)
end)

describe("TimedTransitionModel:BindToPaneVisbility", function()
	it("mirrors visibility in both directions", function()
		local controller = setup()
		local pane = BasicPane.new()

		controller.model:BindToPaneVisbility(pane)

		pane:Show(true)
		expect(controller.model:IsVisible()).toBe(true)

		controller.model:Hide(true)
		expect(pane:IsVisible()).toBe(false)

		pane:Destroy()
		controller:Destroy()
	end)

	it("does not throw when unbinding after the model is destroyed", function()
		local controller = setup()
		local pane = BasicPane.new()

		local unbind = controller.model:BindToPaneVisbility(pane)
		controller:Destroy()

		expect(function()
			unbind()
		end).never.toThrow()

		pane:Destroy()
	end)
end)

describe("TimedTransitionModel duck typing", function()
	it("is transition shaped", function()
		local controller = setup()

		expect(TransitionUtils.isTransition(controller.model)).toBe(true)

		controller:Destroy()
	end)

	it("is recognized as a transition model", function()
		local controller = setup()

		expect(TransitionModel.isTransitionModel(controller.model)).toBe(true)

		controller:Destroy()
	end)
end)

describe("TimedTransitionModel in-flight snap", function()
	it("snaps an already-running show", function()
		local controller = setup()

		controller.model:Show()
		expect(controller.model:IsShowingComplete()).toBe(false)

		controller.model:Show(true)

		expect(controller.model:IsShowingComplete()).toBe(true)
		expect(controller.position()).toBe(1)

		controller:Destroy()
	end)

	it("snaps an already-running hide", function()
		local controller = setup()

		controller.model:Show(true)
		controller.model:Hide()
		expect(controller.model:IsHidingComplete()).toBe(false)

		controller.model:Hide(true)

		expect(controller.model:IsHidingComplete()).toBe(true)
		expect(controller.position()).toBe(0)

		controller:Destroy()
	end)
end)
