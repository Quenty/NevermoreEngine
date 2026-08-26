--!strict
--[[
	@class AccelTweenTransitionModel.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local AccelTweenTransitionModel = require("AccelTweenTransitionModel")
local BasicPane = require("BasicPane")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local TransitionModel = require("TransitionModel")
local TransitionUtils = require("TransitionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	model: AccelTweenTransitionModel.AccelTweenTransitionModel,
	value: () -> number,
	advance: (seconds: number) -> (),
	destroy: () -> (),
}

-- Completion is observed off the animation step, so the clock has to move and then a frame has to
-- pass before the transition notices it arrived.
local function setup(options: { showTarget: number?, hideTarget: number? }?): Controller
	local maid = Maid.new()

	local model: any =
		maid:Add(AccelTweenTransitionModel.new(options and options.showTarget, options and options.hideTarget))

	local now = 0
	model._accelTween:SetClock(function()
		return now
	end)

	local controller = {
		model = model,
		value = function()
			return model:GetPosition()
		end,
		advance = function(seconds: number)
			now += seconds
			task.wait()
			task.wait()
		end,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("AccelTweenTransitionModel.new", function()
	it("starts hidden with hiding already complete", function()
		local controller = setup()

		expect(controller.model:IsVisible()).toBe(false)
		expect(controller.model:IsShowingComplete()).toBe(false)
		expect(controller.model:IsHidingComplete()).toBe(true)
		expect(controller.value()).toBe(0)

		controller.destroy()
	end)

	it("defaults to a show target of 1 and a hide target of 0", function()
		local controller = setup()

		controller.model:Show(true)
		expect(controller.value()).toBe(1)

		controller.model:Hide(true)
		expect(controller.value()).toBe(0)

		controller.destroy()
	end)

	it("honors explicit show and hide targets", function()
		local controller = setup({ showTarget = 8, hideTarget = 3 })

		expect(controller.value()).toBe(3)

		controller.model:Show(true)
		expect(controller.value()).toBe(8)

		controller.destroy()
	end)

	it("rejects a show target that is not a number", function()
		expect(function()
			AccelTweenTransitionModel.new("wide" :: any)
		end).toThrow("Bad showTarget")
	end)

	it("is a basic pane", function()
		local controller = setup()

		expect(BasicPane.isBasicPane(controller.model)).toBe(true)

		controller.destroy()
	end)
end)

describe("AccelTweenTransitionModel visibility", function()
	it("targets the show target without arriving immediately", function()
		local controller = setup()

		controller.model:Show()

		expect(controller.model:IsVisible()).toBe(true)
		expect(controller.model:IsShowingComplete()).toBe(false)
		expect(controller.model:IsHidingComplete()).toBe(false)
		expect(controller.value()).toBe(0)

		controller.destroy()
	end)

	it("completes showing once the tween arrives", function()
		local controller = setup()

		controller.model:Show()
		controller.advance(5)

		expect(controller.model:IsShowingComplete()).toBe(true)
		expect(controller.value()).toBeCloseTo(1)

		controller.destroy()
	end)

	it("completes hiding once the tween arrives", function()
		local controller = setup()

		controller.model:Show(true)
		controller.model:Hide()
		controller.advance(5)

		expect(controller.model:IsHidingComplete()).toBe(true)
		expect(controller.value()).toBeCloseTo(0)

		controller.destroy()
	end)

	it("never overshoots the show target", function()
		local controller = setup()

		controller.model:Show()

		for _ = 1, 20 do
			controller.advance(0.01)
			expect(controller.value() <= 1).toBe(true)
		end

		controller.destroy()
	end)

	it("completes immediately when told not to animate", function()
		local controller = setup()

		controller.model:Show(true)

		expect(controller.model:IsShowingComplete()).toBe(true)
		expect(controller.model:GetVelocity()).toBe(0)
		expect(controller.model:GetRemainingTime()).toBe(0)

		controller.destroy()
	end)

	it("toggles visibility", function()
		local controller = setup()

		controller.model:Toggle(true)
		expect(controller.model:IsVisible()).toBe(true)

		controller.model:Toggle(true)
		expect(controller.model:IsVisible()).toBe(false)

		controller.destroy()
	end)
end)

describe("AccelTweenTransitionModel:SetShowTarget", function()
	it("retargets an already-shown model", function()
		local controller = setup()

		controller.model:Show(true)
		controller.model:SetShowTarget(0.5, true)

		expect(controller.value()).toBe(0.5)

		controller.destroy()
	end)

	it("leaves a hidden model at the hide target", function()
		local controller = setup()

		controller.model:SetShowTarget(0.5, true)

		expect(controller.value()).toBe(0)

		controller.model:Show(true)
		expect(controller.value()).toBe(0.5)

		controller.destroy()
	end)
end)

describe("AccelTweenTransitionModel:SetHideTarget", function()
	it("retargets an already-hidden model", function()
		local controller = setup()

		controller.model:SetHideTarget(0.25, true)

		expect(controller.value()).toBe(0.25)

		controller.destroy()
	end)
end)

describe("AccelTweenTransitionModel:SetAcceleration", function()
	it("reaches the target sooner at a higher acceleration", function()
		local slow = setup()
		local fast = setup()

		slow.model:SetAcceleration(1)
		fast.model:SetAcceleration(500)

		slow.model:Show()
		fast.model:Show()
		slow.advance(0.5)
		fast.advance(0.5)

		expect(fast.model:IsShowingComplete()).toBe(true)
		expect(slow.model:IsShowingComplete()).toBe(false)

		slow.destroy()
		fast.destroy()
	end)

	it("reports the acceleration it was given", function()
		local controller = setup()

		controller.model:SetAcceleration(50)

		expect(controller.model:GetAcceleration()).toBe(50)

		controller.destroy()
	end)

	it("rejects an acceleration that is not a number", function()
		local controller = setup()

		expect(function()
			controller.model:SetAcceleration("fast" :: any)
		end).toThrow("Bad acceleration")

		controller.destroy()
	end)
end)

describe("AccelTweenTransitionModel promises", function()
	it("promises the show until the tween arrives", function()
		local controller = setup()

		local promise = controller.model:PromiseShow()
		expect(promise:IsPending()).toBe(true)

		controller.advance(5)

		expect(promise:IsFulfilled()).toBe(true)

		controller.destroy()
	end)

	it("promises the hide until the tween arrives", function()
		local controller = setup()

		controller.model:Show(true)

		local promise = controller.model:PromiseHide()
		expect(promise:IsPending()).toBe(true)

		controller.advance(5)

		expect(promise:IsFulfilled()).toBe(true)

		controller.destroy()
	end)

	it("resolves without waiting when told not to animate", function()
		local controller = setup()

		expect(controller.model:PromiseShow(true):IsFulfilled()).toBe(true)

		controller.destroy()
	end)

	it("promises the toggle in whichever direction it goes", function()
		local controller = setup()

		expect(controller.model:PromiseToggle(true):IsFulfilled()).toBe(true)
		expect(controller.model:IsVisible()).toBe(true)

		expect(controller.model:PromiseToggle(true):IsFulfilled()).toBe(true)
		expect(controller.model:IsVisible()).toBe(false)

		controller.destroy()
	end)

	it("fires ShowingComplete once the tween arrives", function()
		local controller = setup()
		local fires = 0
		controller.model.ShowingComplete:Connect(function()
			fires += 1
		end)

		controller.model:Show()
		expect(fires).toBe(0)

		controller.advance(5)
		expect(fires).toBe(1)

		controller.destroy()
	end)
end)

describe("AccelTweenTransitionModel:Observe", function()
	it("emits the position while animating and stops once it arrives", function()
		local controller = setup()

		local values = {}
		local sub = controller.model:Observe():Subscribe(function(value)
			table.insert(values, value)
		end)

		controller.model:Show()
		controller.advance(5)

		expect(#values > 1).toBe(true)
		expect(values[#values]).toBeCloseTo(1)

		sub:Destroy()
		controller.destroy()
	end)
end)

describe("AccelTweenTransitionModel:BindToPaneVisbility", function()
	it("mirrors visibility in both directions", function()
		local controller = setup()
		local pane = BasicPane.new()

		controller.model:BindToPaneVisbility(pane)

		pane:Show(true)
		expect(controller.model:IsVisible()).toBe(true)

		controller.model:Hide(true)
		expect(pane:IsVisible()).toBe(false)

		pane:Destroy()
		controller.destroy()
	end)

	it("does not throw when unbinding after the model is destroyed", function()
		local controller = setup()
		local pane = BasicPane.new()

		local unbind = controller.model:BindToPaneVisbility(pane)
		controller.destroy()

		expect(function()
			unbind()
		end).never.toThrow()

		pane:Destroy()
	end)
end)

describe("AccelTweenTransitionModel duck typing", function()
	it("is transition shaped", function()
		local controller = setup()

		expect(TransitionUtils.isTransition(controller.model)).toBe(true)

		controller.destroy()
	end)

	it("is recognized as a transition model", function()
		local controller = setup()

		expect(TransitionModel.isTransitionModel(controller.model)).toBe(true)

		controller.destroy()
	end)

	it("is recognized as an accel tween transition model", function()
		local controller = setup()

		expect(AccelTweenTransitionModel.isAccelTweenTransitionModel(controller.model)).toBe(true)

		controller.destroy()
	end)
end)

describe("AccelTweenTransitionModel in-flight snap", function()
	it("snaps an already-running show", function()
		local controller = setup()

		controller.model:Show()
		expect(controller.model:IsShowingComplete()).toBe(false)

		controller.model:Show(true)

		expect(controller.model:IsShowingComplete()).toBe(true)
		expect(controller.value()).toBe(1)

		controller.destroy()
	end)

	it("snaps an already-running hide", function()
		local controller = setup()

		controller.model:Show(true)
		controller.model:Hide()
		expect(controller.model:IsHidingComplete()).toBe(false)

		controller.model:Hide(true)

		expect(controller.model:IsHidingComplete()).toBe(true)
		expect(controller.value()).toBe(0)

		controller.destroy()
	end)
end)
