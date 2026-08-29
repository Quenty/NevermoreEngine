--!strict
--[[
	@class CameraStateTweener.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local CameraStack = require("CameraStack")
local CameraStackService = require("CameraStackService")
local CameraState = require("CameraState")
local CameraStateTweener = require("CameraStateTweener")
local CustomCameraEffect = require("CustomCameraEffect")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local PlayerMock = require("PlayerMock")
local ServiceBag = require("ServiceBag")
local TransitionModel = require("TransitionModel")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

type Controller = {
	cameraStack: CameraStack.CameraStack,
	cameraEffect: CustomCameraEffect.CustomCameraEffect,
	tweener: CameraStateTweener.CameraStateTweener,
	advance: (seconds: number) -> (),
	Destroy: (self: Controller) -> (),
}

local function makeEffect(): CustomCameraEffect.CustomCameraEffect
	local state = CameraState.new()
	return CustomCameraEffect.new(function()
		return state
	end)
end

local function setup(options: { speed: number? }?): Controller
	local maid = Maid.new()

	local cameraStack = CameraStack.new()
	local cameraEffect = makeEffect()
	local tweener = CameraStateTweener.new(cameraStack, cameraEffect, options and options.speed)

	maid:GiveTask(function()
		if tweener.Destroy then
			tweener:Destroy()
		end
		cameraStack:Destroy()
	end)

	local now = 0
	local fader: any = tweener:GetFader()
	fader.Spring.Clock = function()
		return now
	end

	local controller: Controller = {
		cameraStack = cameraStack,
		cameraEffect = cameraEffect,
		tweener = tweener,
		-- Completion is observed off the animation step, so the clock has to move and then
		-- a frame has to pass before the transition notices it arrived.
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

describe("CameraStateTweener.new", function()
	it("adds a fader to the camera stack above a new state below", function()
		local controller = setup()

		expect(controller.cameraStack:GetIndex(controller.tweener:GetFader())).never.toBeNil()
		expect(controller.tweener:GetCameraEffect()).toBe(controller.cameraEffect)
		expect(controller.tweener:GetCameraBelow()).never.toBe(controller.cameraEffect)

		controller:Destroy()
	end)

	it("starts fully hidden", function()
		local controller = setup()

		expect(controller.tweener:GetPercentVisible()).toBe(0)
		expect(controller.tweener:IsFinishedHiding()).toBe(true)
		expect(controller.tweener:IsFinishedShowing()).toBe(false)

		controller:Destroy()
	end)

	it("defaults to a speed of 20", function()
		local controller = setup()

		expect((controller.tweener:GetFader() :: any).Speed).toBe(20)

		controller:Destroy()
	end)

	it("honors an explicit speed", function()
		local controller = setup({ speed = 5 })

		expect((controller.tweener:GetFader() :: any).Speed).toBe(5)

		controller:Destroy()
	end)

	it("accepts a service bag holding a CameraStackService", function()
		local player = PlayerMock.new({ UserId = 66123202 })
		player.Parent = Workspace
		local restoreLocalPlayer = PlayerMock.setMockedLocalPlayer(player)

		local serviceBag = ServiceBag.new()
		local service: CameraStackService.CameraStackService = serviceBag:GetService(CameraStackService) :: any
		serviceBag:Init()
		serviceBag:Start()

		local tweener = CameraStateTweener.new(serviceBag, makeEffect())

		expect(service:GetCameraStack():GetIndex(tweener:GetFader())).never.toBeNil()

		tweener:Destroy()
		serviceBag:Destroy()
		restoreLocalPlayer()
		player:Destroy()
	end)

	it("rejects a missing camera effect", function()
		local cameraStack = CameraStack.new()

		expect(function()
			CameraStateTweener.new(cameraStack, nil)
		end).toThrow("No cameraEffect")

		cameraStack:Destroy()
	end)

	it("rejects a first argument that is neither a service bag nor a camera stack", function()
		expect(function()
			CameraStateTweener.new({} :: any, makeEffect())
		end).toThrow("Bad serviceBagOrCameraStack")
	end)
end)

describe("CameraStateTweener:Show", function()
	it("targets fully visible without arriving immediately", function()
		local controller = setup()

		controller.tweener:Show()

		expect((controller.tweener:GetFader() :: any).Target).toBe(1)
		expect(controller.tweener:GetPercentVisible()).toBe(0)
		expect(controller.tweener:IsFinishedShowing()).toBe(false)
		expect(controller.tweener:IsFinishedHiding()).toBe(false)

		controller:Destroy()
	end)

	it("arrives once enough time passes", function()
		local controller = setup()

		controller.tweener:Show()
		controller.advance(5)

		expect(controller.tweener:GetPercentVisible()).toBe(1)
		expect(controller.tweener:IsFinishedShowing()).toBe(true)
		expect(controller.tweener:IsFinishedHiding()).toBe(false)

		controller:Destroy()
	end)

	it("snaps when told not to animate", function()
		local controller = setup()

		controller.tweener:Show(true)

		expect(controller.tweener:GetPercentVisible()).toBe(1)
		expect(controller.tweener:IsFinishedShowing()).toBe(true)

		controller:Destroy()
	end)

	it("snaps an already-running show when told not to animate", function()
		local controller = setup()

		controller.tweener:Show()
		expect(controller.tweener:IsFinishedShowing()).toBe(false)

		controller.tweener:Show(true)

		expect(controller.tweener:GetPercentVisible()).toBe(1)
		expect(controller.tweener:IsFinishedShowing()).toBe(true)

		controller:Destroy()
	end)
end)

describe("CameraStateTweener:Hide", function()
	it("targets fully hidden without arriving immediately", function()
		local controller = setup()

		controller.tweener:Show(true)
		controller.tweener:Hide()

		expect((controller.tweener:GetFader() :: any).Target).toBe(0)
		expect(controller.tweener:GetPercentVisible()).toBe(1)
		expect(controller.tweener:IsFinishedHiding()).toBe(false)

		controller:Destroy()
	end)

	it("arrives once enough time passes", function()
		local controller = setup()

		controller.tweener:Show(true)
		controller.tweener:Hide()
		controller.advance(5)

		expect(controller.tweener:GetPercentVisible()).toBe(0)
		expect(controller.tweener:IsFinishedHiding()).toBe(true)

		controller:Destroy()
	end)

	it("snaps when told not to animate", function()
		local controller = setup()

		controller.tweener:Show(true)
		controller.tweener:Hide(true)

		expect(controller.tweener:GetPercentVisible()).toBe(0)
		expect(controller.tweener:IsFinishedHiding()).toBe(true)

		controller:Destroy()
	end)
end)

describe("CameraStateTweener:SetVisible", function()
	it("shows when visible", function()
		local controller = setup()

		controller.tweener:SetVisible(true, true)

		expect(controller.tweener:GetPercentVisible()).toBe(1)

		controller:Destroy()
	end)

	it("hides when not visible", function()
		local controller = setup()

		controller.tweener:Show(true)
		controller.tweener:SetVisible(false, true)

		expect(controller.tweener:GetPercentVisible()).toBe(0)

		controller:Destroy()
	end)
end)

describe("CameraStateTweener:SetTarget", function()
	it("targets a partial value", function()
		local controller = setup()

		controller.tweener:SetTarget(0.5)
		controller.advance(5)

		expect(controller.tweener:GetPercentVisible()).toBe(0.5)

		controller:Destroy()
	end)

	it("snaps to a partial value when told not to animate", function()
		local controller = setup()

		controller.tweener:SetTarget(0.5, true)

		expect(controller.tweener:GetPercentVisible()).toBe(0.5)

		controller:Destroy()
	end)

	it("returns itself so calls can chain", function()
		local controller = setup()

		expect(controller.tweener:SetTarget(1)).toBe(controller.tweener)

		controller:Destroy()
	end)

	it("hides on a target of zero without discarding the shown target", function()
		local controller = setup()

		controller.tweener:SetTarget(0.5, true)
		controller.tweener:SetTarget(0, true)

		expect(controller.tweener:IsVisible()).toBe(false)
		expect(controller.tweener:GetShownTarget()).toBe(0.5)

		controller.tweener:Show(true)

		expect(controller.tweener:GetPercentVisible()).toBe(0.5)

		controller:Destroy()
	end)

	it("rejects a target that is not a number", function()
		local controller = setup()

		expect(function()
			controller.tweener:SetTarget(nil :: any)
		end).toThrow("Bad target")

		controller:Destroy()
	end)
end)

describe("CameraStateTweener:SetShownTarget", function()
	it("fades to the shown target rather than fully visible", function()
		local controller = setup()

		controller.tweener:SetShownTarget(0.25)
		controller.tweener:Show(true)

		expect(controller.tweener:GetShownTarget()).toBe(0.25)
		expect(controller.tweener:GetPercentVisible()).toBe(0.25)

		controller:Destroy()
	end)

	it("retargets and runs the show transition again when changed while shown", function()
		local controller = setup()
		local showingComplete = 0
		controller.tweener.ShowingComplete:Connect(function()
			showingComplete += 1
		end)

		controller.tweener:Show(true)
		expect(showingComplete).toBe(1)

		controller.tweener:SetShownTarget(0.5)

		expect(controller.tweener:IsShowingComplete()).toBe(false)
		expect((controller.tweener:GetFader() :: any).Target).toBe(0.5)

		controller.advance(5)

		expect(showingComplete).toBe(2)
		expect(controller.tweener:GetPercentVisible()).toBe(0.5)

		controller:Destroy()
	end)

	it("does not start a transition when changed while hidden", function()
		local controller = setup()

		controller.tweener:SetShownTarget(0.5)

		expect((controller.tweener:GetFader() :: any).Target).toBe(0)
		expect(controller.tweener:IsHidingComplete()).toBe(true)

		controller:Destroy()
	end)
end)

describe("CameraStateTweener as a transition model", function()
	it("is recognized as a transition model", function()
		local controller = setup()

		expect(TransitionModel.isTransitionModel(controller.tweener)).toBe(true)

		controller:Destroy()
	end)

	it("promises the show until the fade arrives", function()
		local controller = setup()

		local promise = controller.tweener:PromiseShow()
		expect(promise:IsPending()).toBe(true)

		controller.advance(5)

		expect(promise:IsFulfilled()).toBe(true)
		expect(controller.tweener:GetPercentVisible()).toBe(1)

		controller:Destroy()
	end)

	it("resolves the show promise without waiting when told not to animate", function()
		local controller = setup()

		expect(controller.tweener:PromiseShow(true):IsFulfilled()).toBe(true)

		controller:Destroy()
	end)

	it("promises the hide until the fade arrives", function()
		local controller = setup()

		controller.tweener:Show(true)

		local promise = controller.tweener:PromiseHide()
		expect(promise:IsPending()).toBe(true)

		controller.advance(5)

		expect(promise:IsFulfilled()).toBe(true)
		expect(controller.tweener:GetPercentVisible()).toBe(0)

		controller:Destroy()
	end)

	it("fires ShowingComplete only once the fade arrives", function()
		local controller = setup()
		local showingComplete = 0
		controller.tweener.ShowingComplete:Connect(function()
			showingComplete += 1
		end)

		controller.tweener:Show()
		expect(showingComplete).toBe(0)

		controller.advance(5)

		expect(showingComplete).toBe(1)

		controller:Destroy()
	end)

	it("toggles visibility", function()
		local controller = setup()

		controller.tweener:Toggle(true)
		expect(controller.tweener:IsVisible()).toBe(true)
		expect(controller.tweener:GetPercentVisible()).toBe(1)

		controller.tweener:Toggle(true)
		expect(controller.tweener:IsVisible()).toBe(false)
		expect(controller.tweener:GetPercentVisible()).toBe(0)

		controller:Destroy()
	end)
end)

describe("CameraStateTweener:Finish", function()
	it("invokes the callback immediately when hiding is already complete", function()
		local controller = setup()
		local calls = 0

		controller.tweener:Show(true)
		controller.tweener:Finish(true, function()
			calls += 1
		end)

		expect(calls).toBe(1)
		expect(controller.tweener:GetPercentVisible()).toBe(0)

		controller:Destroy()
	end)

	it("waits for the hide to complete before invoking the callback", function()
		local controller = setup()
		local calls = 0

		controller.tweener:Show(true)
		controller.tweener:Finish(false, function()
			calls += 1
		end)

		expect(calls).toBe(0)
		expect((controller.tweener:GetFader() :: any).Target).toBe(0)

		controller:Destroy()
	end)

	it("rejects a callback that is not a function", function()
		local controller = setup()

		expect(function()
			controller.tweener:Finish(true, nil :: any)
		end).toThrow("Bad callback")

		controller:Destroy()
	end)
end)

describe("CameraStateTweener:SetSpeed", function()
	it("updates the fader speed and returns itself", function()
		local controller = setup()

		expect(controller.tweener:SetSpeed(40)).toBe(controller.tweener)
		expect((controller.tweener:GetFader() :: any).Speed).toBe(40)

		controller:Destroy()
	end)

	it("rejects a speed that is not a number", function()
		local controller = setup()

		expect(function()
			controller.tweener:SetSpeed("fast" :: any)
		end).toThrow("Bad speed")

		controller:Destroy()
	end)
end)

describe("CameraStateTweener:SetEpsilon", function()
	it("updates the fader epsilon", function()
		local controller = setup()

		controller.tweener:SetEpsilon(0.1)

		expect((controller.tweener:GetFader() :: any).Epsilon).toBe(0.1)

		controller:Destroy()
	end)

	it("counts the tween as arrived sooner than the default epsilon would", function()
		local strict = setup()
		local loose = setup()

		loose.tweener:SetEpsilon(0.5)

		strict.tweener:Show()
		loose.tweener:Show()
		strict.advance(0.3)
		loose.advance(0.3)

		expect(loose.tweener:IsFinishedShowing()).toBe(true)
		expect(strict.tweener:IsFinishedShowing()).toBe(false)

		strict:Destroy()
		loose:Destroy()
	end)
end)

describe("CameraStateTweener:Destroy", function()
	it("removes the fader from the camera stack", function()
		local controller = setup()
		local fader = controller.tweener:GetFader()

		expect(controller.cameraStack:GetIndex(fader)).never.toBeNil()

		controller.tweener:Destroy()

		expect(controller.cameraStack:GetIndex(fader)).toBeNil()

		controller:Destroy()
	end)
end)
