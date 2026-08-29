--!strict
--[[
	@class SpringTransitionModel.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local SpringTransitionModel = require("SpringTransitionModel")
local TransitionModel = require("TransitionModel")
local TransitionUtils = require("TransitionUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	model: SpringTransitionModel.SpringTransitionModel<number>,
	value: () -> number,
	advance: (seconds: number) -> (),
	Destroy: (self: Controller) -> (),
}

-- Completion is observed off the animation step, so the clock has to move and then a frame has to
-- pass before the transition notices it arrived.
local function setup(options: { showTarget: number?, hideTarget: number? }?): Controller
	local maid = Maid.new()

	local model: any =
		maid:Add(SpringTransitionModel.new(options and options.showTarget, options and options.hideTarget))

	local now = 0
	model._springObject:SetClock(function()
		return now
	end)

	local controller: Controller = {
		model = model,
		value = function()
			return model._springObject.Value
		end,
		advance = function(seconds: number)
			now += seconds
			task.wait()
			task.wait()
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("SpringTransitionModel.new", function()
	it("starts hidden with hiding already complete", function()
		local controller = setup()

		expect(controller.model:IsVisible()).toBe(false)
		expect(controller.model:IsShowingComplete()).toBe(false)
		expect(controller.model:IsHidingComplete()).toBe(true)
		expect(controller.value()).toBe(0)

		controller:Destroy()
	end)

	it("defaults to a show target of 1 and a hide target of 0", function()
		local controller = setup()

		controller.model:Show(true)
		expect(controller.value()).toBe(1)

		controller.model:Hide(true)
		expect(controller.value()).toBe(0)

		controller:Destroy()
	end)

	it("honors explicit show and hide targets", function()
		local controller = setup({ showTarget = 8, hideTarget = 3 })

		expect(controller.value()).toBe(3)

		controller.model:Show(true)
		expect(controller.value()).toBe(8)

		controller:Destroy()
	end)

	it("is a basic pane", function()
		local controller = setup()

		expect(BasicPane.isBasicPane(controller.model)).toBe(true)

		controller:Destroy()
	end)
end)

describe("SpringTransitionModel visibility", function()
	it("targets the show target without arriving immediately", function()
		local controller = setup()

		controller.model:Show()

		expect(controller.model:IsVisible()).toBe(true)
		expect(controller.model:IsShowingComplete()).toBe(false)
		expect(controller.model:IsHidingComplete()).toBe(false)
		expect(controller.value()).toBe(0)

		controller:Destroy()
	end)

	it("completes showing once the spring settles", function()
		local controller = setup()

		controller.model:Show()
		controller.advance(5)

		expect(controller.model:IsShowingComplete()).toBe(true)
		expect(controller.value()).toBeCloseTo(1)

		controller:Destroy()
	end)

	it("completes hiding once the spring settles", function()
		local controller = setup()

		controller.model:Show(true)
		controller.model:Hide()
		controller.advance(5)

		expect(controller.model:IsHidingComplete()).toBe(true)
		expect(controller.value()).toBeCloseTo(0)

		controller:Destroy()
	end)

	it("completes immediately when told not to animate", function()
		local controller = setup()

		controller.model:Show(true)

		expect(controller.model:IsShowingComplete()).toBe(true)
		expect(controller.model:GetVelocity()).toBe(0)

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

describe("SpringTransitionModel:SetShowTarget", function()
	it("retargets an already-shown model", function()
		local controller = setup()

		controller.model:Show(true)
		controller.model:SetShowTarget(0.5, true)

		expect(controller.value()).toBe(0.5)

		controller:Destroy()
	end)

	it("leaves a hidden model at the hide target", function()
		local controller = setup()

		controller.model:SetShowTarget(0.5, true)

		expect(controller.value()).toBe(0)

		controller.model:Show(true)
		expect(controller.value()).toBe(0.5)

		controller:Destroy()
	end)
end)

describe("SpringTransitionModel:SetHideTarget", function()
	it("retargets an already-hidden model", function()
		local controller = setup()

		controller.model:SetHideTarget(0.25, true)

		expect(controller.value()).toBe(0.25)

		controller:Destroy()
	end)
end)

describe("SpringTransitionModel:SetSpeed", function()
	it("reaches the target sooner at a higher speed", function()
		local slow = setup()
		local fast = setup()

		slow.model:SetSpeed(1)
		fast.model:SetSpeed(100)

		slow.model:Show()
		fast.model:Show()
		slow.advance(0.5)
		fast.advance(0.5)

		expect(fast.model:IsShowingComplete()).toBe(true)
		expect(slow.model:IsShowingComplete()).toBe(false)

		slow:Destroy()
		fast:Destroy()
	end)

	it("rejects a speed that is not a number", function()
		local controller = setup()

		expect(function()
			controller.model:SetSpeed("fast" :: any)
		end).toThrow("Bad speed")

		controller:Destroy()
	end)
end)

describe("SpringTransitionModel:SetEpsilon", function()
	it("rejects an epsilon that is not a number", function()
		local controller = setup()

		expect(function()
			controller.model:SetEpsilon("wide" :: any)
		end).toThrow("Bad epsilon")

		controller:Destroy()
	end)
end)

describe("SpringTransitionModel promises", function()
	it("promises the show until the spring settles", function()
		local controller = setup()

		local promise = controller.model:PromiseShow()
		expect(promise:IsPending()).toBe(true)

		controller.advance(5)

		expect(promise:IsFulfilled()).toBe(true)

		controller:Destroy()
	end)

	it("promises the hide until the spring settles", function()
		local controller = setup()

		controller.model:Show(true)

		local promise = controller.model:PromiseHide()
		expect(promise:IsPending()).toBe(true)

		controller.advance(5)

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

	it("fires ShowingComplete once the spring settles", function()
		local controller = setup()
		local fires = 0
		controller.model.ShowingComplete:Connect(function()
			fires += 1
		end)

		controller.model:Show()
		expect(fires).toBe(0)

		controller.advance(5)
		expect(fires).toBe(1)

		controller:Destroy()
	end)
end)

describe("SpringTransitionModel:BindToPaneVisbility", function()
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

describe("SpringTransitionModel duck typing", function()
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

describe("SpringTransitionModel in-flight snap", function()
	it("snaps an already-running show", function()
		local controller = setup()

		controller.model:Show()
		expect(controller.model:IsShowingComplete()).toBe(false)

		controller.model:Show(true)

		expect(controller.model:IsShowingComplete()).toBe(true)
		expect(controller.value()).toBe(1)

		controller:Destroy()
	end)

	it("snaps an already-running hide", function()
		local controller = setup()

		controller.model:Show(true)
		controller.model:Hide()
		expect(controller.model:IsHidingComplete()).toBe(false)

		controller.model:Hide(true)

		expect(controller.model:IsHidingComplete()).toBe(true)
		expect(controller.value()).toBe(0)

		controller:Destroy()
	end)
end)
