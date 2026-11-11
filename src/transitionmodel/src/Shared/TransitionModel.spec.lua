--!strict
local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Signal = require("Signal")
local TransitionModel = require("TransitionModel")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup(): any
	local maid = Maid.new()

	local transitionModel: TransitionModel.TransitionModel = maid:Add(TransitionModel.new())

	local controller = {
		maid = maid,
		transitionModel = transitionModel,
		trackFires = function(signal: Signal.Signal<()>): () -> number
			local count = 0

			maid:GiveTask(signal:Connect(function()
				count += 1
			end))

			return function()
				return count
			end
		end,
		trackValues = function(observable: Observable.Observable<boolean>): { boolean }
			local values = {}

			maid:GiveTask(observable:Subscribe(function(value)
				table.insert(values, value)
			end))

			return values
		end,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("TransitionModel.new", function()
	it("starts hidden with hiding already complete", function()
		local controller = setup()

		expect(controller.transitionModel:IsVisible()).toBe(false)
		expect(controller.transitionModel:IsShowingComplete()).toBe(false)
		expect(controller.transitionModel:IsHidingComplete()).toBe(true)

		controller:Destroy()
	end)
end)

describe("TransitionModel.isTransitionModel", function()
	it("recognizes a transition model", function()
		local controller = setup()

		expect(TransitionModel.isTransitionModel(controller.transitionModel)).toBe(true)

		controller:Destroy()
	end)

	it("rejects a plain basic pane", function()
		local controller = setup()

		expect(TransitionModel.isTransitionModel(controller.maid:Add(BasicPane.new()))).toBe(false)

		controller:Destroy()
	end)

	it("rejects values that are not transition models", function()
		local controller = setup()

		expect(TransitionModel.isTransitionModel(nil)).toBe(false)
		expect(TransitionModel.isTransitionModel({})).toBe(false)
		expect(TransitionModel.isTransitionModel(5)).toBe(false)

		controller:Destroy()
	end)
end)

describe("transitions without callbacks", function()
	it("completes showing immediately", function()
		local controller = setup()

		local showingComplete = controller.trackFires(controller.transitionModel.ShowingComplete)

		controller.transitionModel:Show()

		expect(controller.transitionModel:IsShowingComplete()).toBe(true)
		expect(controller.transitionModel:IsHidingComplete()).toBe(false)
		expect(showingComplete()).toBe(1)

		controller:Destroy()
	end)

	it("completes hiding immediately", function()
		local controller = setup()

		controller.transitionModel:Show()

		local hidingComplete = controller.trackFires(controller.transitionModel.HidingComplete)

		controller.transitionModel:Hide()

		expect(controller.transitionModel:IsHidingComplete()).toBe(true)
		expect(controller.transitionModel:IsShowingComplete()).toBe(false)
		expect(hidingComplete()).toBe(1)

		controller:Destroy()
	end)

	it("does not re-run a transition set to the visibility it already has", function()
		local controller = setup()

		local showingComplete = controller.trackFires(controller.transitionModel.ShowingComplete)

		controller.transitionModel:Show()
		controller.transitionModel:Show()

		expect(showingComplete()).toBe(1)

		controller:Destroy()
	end)
end)

describe("TransitionModel:SetVisible", function()
	it("snaps an in-flight transition when re-set to the same visibility with doNotAnimate", function()
		local controller = setup()

		local calls = 0
		local lastDoNotAnimate: boolean? = nil
		controller.transitionModel:SetPromiseShow(function(_callbackMaid: Maid.Maid, doNotAnimate: boolean?)
			calls += 1
			lastDoNotAnimate = doNotAnimate
			return if doNotAnimate then Promise.resolved() else Promise.new()
		end)

		controller.transitionModel:Show()
		expect(calls).toBe(1)
		expect(controller.transitionModel:IsShowingComplete()).toBe(false)

		controller.transitionModel:Show(true)

		expect(calls).toBe(2)
		expect(lastDoNotAnimate).toBe(true)
		expect(controller.transitionModel:IsShowingComplete()).toBe(true)

		controller:Destroy()
	end)

	it("does not restart a completed transition re-set with doNotAnimate", function()
		local controller = setup()

		local showingComplete = controller.trackFires(controller.transitionModel.ShowingComplete)

		controller.transitionModel:Show()
		expect(showingComplete()).toBe(1)

		controller.transitionModel:Show(true)

		expect(showingComplete()).toBe(1)

		controller:Destroy()
	end)

	it("rejects a visibility that is not a boolean", function()
		local controller = setup()

		expect(function()
			controller.transitionModel:SetVisible(5 :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("TransitionModel.SkipAnimationRequested", function()
	it("fires when asked for the visibility already held with doNotAnimate", function()
		local controller = setup()

		local fired: { boolean } = {}
		controller.maid:GiveTask(controller.transitionModel.SkipAnimationRequested:Connect(function(isVisible)
			table.insert(fired, isVisible)
		end))

		controller.transitionModel:Hide(true)
		controller.transitionModel:Show()
		controller.transitionModel:Show(true)

		expect(fired).toEqual({ false, true })

		controller:Destroy()
	end)

	it("does not fire when the visibility actually changes", function()
		local controller = setup()

		local fires = controller.trackFires(controller.transitionModel.SkipAnimationRequested :: any)

		controller.transitionModel:Show(true)
		controller.transitionModel:Hide(true)

		expect(fires()).toBe(0)

		controller:Destroy()
	end)

	it("does not fire without doNotAnimate", function()
		local controller = setup()

		local fires = controller.trackFires(controller.transitionModel.SkipAnimationRequested :: any)

		controller.transitionModel:Show()
		controller.transitionModel:Show()

		expect(fires()).toBe(0)

		controller:Destroy()
	end)

	it("lets a listener snap alongside the model's own transition", function()
		local controller = setup()

		local snapped = 0
		controller.maid:GiveTask(controller.transitionModel.SkipAnimationRequested:Connect(function()
			snapped += 1
		end))

		controller.transitionModel:SetPromiseShow(function(_callbackMaid: Maid.Maid, doNotAnimate: boolean?)
			return if doNotAnimate then Promise.resolved() else Promise.new()
		end)

		controller.transitionModel:Show()
		expect(controller.transitionModel:IsShowingComplete()).toBe(false)

		controller.transitionModel:Show(true)

		expect(snapped).toBe(1)
		expect(controller.transitionModel:IsShowingComplete()).toBe(true)

		controller:Destroy()
	end)
end)

describe("TransitionModel:_restartTransition", function()
	it("re-runs the show callback while visible", function()
		local controller = setup()

		local shown, hidden = 0, 0
		controller.transitionModel:SetPromiseShow(function()
			shown += 1
			return Promise.resolved()
		end)
		controller.transitionModel:SetPromiseHide(function()
			hidden += 1
			return Promise.resolved()
		end)

		controller.transitionModel:Show()
		expect(shown).toBe(1)

		controller.transitionModel:_restartTransition()

		expect(shown).toBe(2)
		expect(hidden).toBe(0)
		expect(controller.transitionModel:IsVisible()).toBe(true)

		controller:Destroy()
	end)

	it("re-runs the hide callback while hidden", function()
		local controller = setup()

		local hidden = 0
		controller.transitionModel:SetPromiseHide(function()
			hidden += 1
			return Promise.resolved()
		end)

		controller.transitionModel:_restartTransition()

		expect(hidden).toBe(1)
		expect(controller.transitionModel:IsVisible()).toBe(false)

		controller:Destroy()
	end)

	it("re-fires the completion signal for the restarted transition", function()
		local controller = setup()

		local showingComplete = controller.trackFires(controller.transitionModel.ShowingComplete)

		controller.transitionModel:Show()
		expect(showingComplete()).toBe(1)

		controller.transitionModel:_restartTransition()

		expect(showingComplete()).toBe(2)

		controller:Destroy()
	end)

	it("abandons the in-flight transition it replaces", function()
		local controller = setup()

		local cleaned = false
		controller.transitionModel:SetPromiseShow(function(callbackMaid: Maid.Maid)
			callbackMaid:GiveTask(function()
				cleaned = true
			end)
			return Promise.new()
		end)

		controller.transitionModel:Show()
		expect(cleaned).toBe(false)

		controller.transitionModel:_restartTransition()

		expect(cleaned).toBe(true)

		controller:Destroy()
	end)

	it("passes doNotAnimate through to the callback", function()
		local controller = setup()

		local lastDoNotAnimate: boolean? = nil
		controller.transitionModel:SetPromiseShow(function(_callbackMaid: Maid.Maid, doNotAnimate: boolean?)
			lastDoNotAnimate = doNotAnimate
			return Promise.resolved()
		end)

		controller.transitionModel:Show()
		expect(lastDoNotAnimate).toBe(nil)

		controller.transitionModel:_restartTransition(true)

		expect(lastDoNotAnimate).toBe(true)

		controller:Destroy()
	end)
end)

describe("TransitionModel:SetPromiseShow", function()
	it("holds showing incomplete until the returned promise resolves", function()
		local controller = setup()

		local callbackPromise = Promise.new()
		controller.transitionModel:SetPromiseShow(function()
			return callbackPromise
		end)

		local showingComplete = controller.trackFires(controller.transitionModel.ShowingComplete)

		controller.transitionModel:Show()
		expect(controller.transitionModel:IsShowingComplete()).toBe(false)
		expect(showingComplete()).toBe(0)

		callbackPromise:Resolve()
		expect(controller.transitionModel:IsShowingComplete()).toBe(true)
		expect(showingComplete()).toBe(1)

		controller:Destroy()
	end)

	it("passes doNotAnimate through to the callback", function()
		local controller = setup()

		local observed: { boolean? } = {}
		controller.transitionModel:SetPromiseShow(function(_callbackMaid: Maid.Maid, doNotAnimate: boolean?)
			table.insert(observed, doNotAnimate)
			return Promise.resolved()
		end)

		controller.transitionModel:Show(true)
		controller.transitionModel:Hide()
		controller.transitionModel:Show()

		expect(observed[1]).toBe(true)
		expect(observed[2]).toBe(nil)

		controller:Destroy()
	end)

	it("cleans up the callback maid when the next transition starts", function()
		local controller = setup()

		local cleaned = false
		controller.transitionModel:SetPromiseShow(function(callbackMaid: Maid.Maid)
			callbackMaid:GiveTask(function()
				cleaned = true
			end)
			return Promise.resolved()
		end)

		controller.transitionModel:Show()
		expect(cleaned).toBe(false)

		controller.transitionModel:Hide()
		expect(cleaned).toBe(true)

		controller:Destroy()
	end)

	it("cleans up the callback maid on destroy", function()
		local controller = setup()

		local cleaned = false
		controller.transitionModel:SetPromiseShow(function(callbackMaid: Maid.Maid)
			callbackMaid:GiveTask(function()
				cleaned = true
			end)
			return Promise.new()
		end)

		controller.transitionModel:Show()
		expect(cleaned).toBe(false)

		controller.maid:DoCleaning()
		expect(cleaned).toBe(true)

		controller:Destroy()
	end)

	it("clears the callback when set to nil", function()
		local controller = setup()

		controller.transitionModel:SetPromiseShow(function()
			return Promise.new()
		end)
		controller.transitionModel:SetPromiseShow(nil)

		controller.transitionModel:Show()

		expect(controller.transitionModel:IsShowingComplete()).toBe(true)

		controller:Destroy()
	end)

	it("rejects a callback that is not a function", function()
		local controller = setup()

		expect(function()
			controller.transitionModel:SetPromiseShow(5 :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("TransitionModel:SetPromiseHide", function()
	it("holds hiding incomplete until the returned promise resolves", function()
		local controller = setup()

		local callbackPromise = Promise.new()
		controller.transitionModel:SetPromiseHide(function()
			return callbackPromise
		end)

		local hidingComplete = controller.trackFires(controller.transitionModel.HidingComplete)

		controller.transitionModel:Show()
		controller.transitionModel:Hide()
		expect(controller.transitionModel:IsHidingComplete()).toBe(false)
		expect(hidingComplete()).toBe(0)

		callbackPromise:Resolve()
		expect(controller.transitionModel:IsHidingComplete()).toBe(true)
		expect(hidingComplete()).toBe(1)

		controller:Destroy()
	end)

	it("abandons an in-flight hide when shown again", function()
		local controller = setup()

		local callbackPromise = Promise.new()
		local cleaned = false
		controller.transitionModel:SetPromiseHide(function(callbackMaid: Maid.Maid)
			callbackMaid:GiveTask(function()
				cleaned = true
			end)
			return callbackPromise
		end)

		controller.transitionModel:Show()
		controller.transitionModel:Hide()
		expect(cleaned).toBe(false)

		controller.transitionModel:Show()
		expect(cleaned).toBe(true)

		callbackPromise:Resolve()
		expect(controller.transitionModel:IsHidingComplete()).toBe(false)

		controller:Destroy()
	end)

	it("rejects a callback that is not a function", function()
		local controller = setup()

		expect(function()
			controller.transitionModel:SetPromiseHide(5 :: any)
		end).toThrow()

		controller:Destroy()
	end)
end)

describe("TransitionModel:PromiseShow", function()
	it("resolves once the show transition completes", function()
		local controller = setup()

		local callbackPromise = Promise.new()
		controller.transitionModel:SetPromiseShow(function()
			return callbackPromise
		end)

		local promise = controller.maid:Add(controller.transitionModel:PromiseShow())
		expect(controller.transitionModel:IsVisible()).toBe(true)
		expect(promise:IsPending()).toBe(true)

		callbackPromise:Resolve()
		expect(promise:IsFulfilled()).toBe(true)

		controller:Destroy()
	end)

	it("resolves immediately when showing is already complete", function()
		local controller = setup()

		controller.transitionModel:Show()

		expect(controller.transitionModel:PromiseShow():IsFulfilled()).toBe(true)

		controller:Destroy()
	end)

	it("rejects when hidden before showing completes", function()
		local controller = setup()

		controller.transitionModel:SetPromiseShow(function()
			return Promise.new()
		end)

		local promise = controller.maid:Add(controller.transitionModel:PromiseShow())
		expect(promise:IsPending()).toBe(true)

		controller.transitionModel:Hide()
		expect(promise:IsRejected()).toBe(true)

		controller:Destroy()
	end)
end)

describe("TransitionModel:PromiseHide", function()
	it("resolves once the hide transition completes", function()
		local controller = setup()

		local callbackPromise = Promise.new()
		controller.transitionModel:SetPromiseHide(function()
			return callbackPromise
		end)

		controller.transitionModel:Show()

		local promise = controller.maid:Add(controller.transitionModel:PromiseHide())
		expect(controller.transitionModel:IsVisible()).toBe(false)
		expect(promise:IsPending()).toBe(true)

		callbackPromise:Resolve()
		expect(promise:IsFulfilled()).toBe(true)

		controller:Destroy()
	end)

	it("resolves immediately when hiding is already complete", function()
		local controller = setup()

		expect(controller.transitionModel:PromiseHide():IsFulfilled()).toBe(true)

		controller:Destroy()
	end)

	it("rejects when shown before hiding completes", function()
		local controller = setup()

		controller.transitionModel:SetPromiseHide(function()
			return Promise.new()
		end)

		controller.transitionModel:Show()

		local promise = controller.maid:Add(controller.transitionModel:PromiseHide())
		expect(promise:IsPending()).toBe(true)

		controller.transitionModel:Show()
		expect(promise:IsRejected()).toBe(true)

		controller:Destroy()
	end)
end)

describe("TransitionModel:PromiseToggle", function()
	it("runs the hide transition when visible", function()
		local controller = setup()

		local shown, hidden = 0, 0
		controller.transitionModel:SetPromiseShow(function()
			shown += 1
			return Promise.resolved()
		end)
		controller.transitionModel:SetPromiseHide(function()
			hidden += 1
			return Promise.resolved()
		end)

		controller.transitionModel:Show()
		expect(shown).toBe(1)

		local promise = controller.maid:Add(controller.transitionModel:PromiseToggle())

		expect(controller.transitionModel:IsVisible()).toBe(false)
		expect(hidden).toBe(1)
		expect(shown).toBe(1)
		expect(controller.transitionModel:IsHidingComplete()).toBe(true)
		expect(promise:IsFulfilled()).toBe(true)

		controller:Destroy()
	end)

	it("runs the show transition when hidden", function()
		local controller = setup()

		local shown, hidden = 0, 0
		controller.transitionModel:SetPromiseShow(function()
			shown += 1
			return Promise.resolved()
		end)
		controller.transitionModel:SetPromiseHide(function()
			hidden += 1
			return Promise.resolved()
		end)

		local promise = controller.maid:Add(controller.transitionModel:PromiseToggle())

		expect(controller.transitionModel:IsVisible()).toBe(true)
		expect(shown).toBe(1)
		expect(hidden).toBe(0)
		expect(controller.transitionModel:IsShowingComplete()).toBe(true)
		expect(promise:IsFulfilled()).toBe(true)

		controller:Destroy()
	end)
end)

describe("TransitionModel:ObserveIsShowingComplete", function()
	it("emits the current state and each change", function()
		local controller = setup()

		local values = controller.trackValues(controller.transitionModel:ObserveIsShowingComplete())

		controller.transitionModel:Show()
		controller.transitionModel:Hide()

		expect(values).toEqual({ false, true, false })

		controller:Destroy()
	end)
end)

describe("TransitionModel:ObserveIsHidingComplete", function()
	it("emits the current state and each change", function()
		local controller = setup()

		local values = controller.trackValues(controller.transitionModel:ObserveIsHidingComplete())

		controller.transitionModel:Show()
		controller.transitionModel:Hide()

		expect(values).toEqual({ true, false, true })

		controller:Destroy()
	end)
end)

describe("TransitionModel:BindToPaneVisbility", function()
	it("adopts the visibility of the pane it binds to", function()
		local controller = setup()

		local pane = controller.maid:Add(BasicPane.new())
		pane:Show()

		controller.transitionModel:BindToPaneVisbility(pane)

		expect(controller.transitionModel:IsVisible()).toBe(true)
		expect(controller.transitionModel:IsShowingComplete()).toBe(true)

		controller:Destroy()
	end)

	it("mirrors visibility in both directions", function()
		local controller = setup()

		local pane = controller.maid:Add(BasicPane.new())
		controller.transitionModel:BindToPaneVisbility(pane)

		pane:Show()
		expect(controller.transitionModel:IsVisible()).toBe(true)

		controller.transitionModel:Hide()
		expect(pane:IsVisible()).toBe(false)

		controller:Destroy()
	end)

	it("stops mirroring once the cleanup function runs", function()
		local controller = setup()

		local pane = controller.maid:Add(BasicPane.new())
		local unbind = controller.transitionModel:BindToPaneVisbility(pane)

		unbind()

		pane:Show()
		expect(controller.transitionModel:IsVisible()).toBe(false)

		controller:Destroy()
	end)

	it("does not tear down a newer binding", function()
		local controller = setup()

		local firstPane = controller.maid:Add(BasicPane.new())
		local secondPane = controller.maid:Add(BasicPane.new())

		local unbindFirst = controller.transitionModel:BindToPaneVisbility(firstPane)
		controller.transitionModel:BindToPaneVisbility(secondPane)

		unbindFirst()

		firstPane:Show()
		expect(controller.transitionModel:IsVisible()).toBe(false)

		secondPane:Show()
		expect(controller.transitionModel:IsVisible()).toBe(true)

		controller:Destroy()
	end)
end)
