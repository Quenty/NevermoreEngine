--!strict
local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Jest = require("Jest")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Signal = require("Signal")
local TransitionModel = require("TransitionModel")

local afterEach = Jest.Globals.afterEach
local beforeEach = Jest.Globals.beforeEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local maid: Maid.Maid = nil :: any
local transitionModel: TransitionModel.TransitionModel = nil :: any

beforeEach(function()
	maid = Maid.new()
	transitionModel = maid:Add(TransitionModel.new())
end)

afterEach(function()
	maid:DoCleaning()
end)

local function trackFires(signal: Signal.Signal<()>): () -> number
	local count = 0

	maid:GiveTask(signal:Connect(function()
		count += 1
	end))

	return function()
		return count
	end
end

local function trackValues(observable: Observable.Observable<boolean>): { boolean }
	local values = {}

	maid:GiveTask(observable:Subscribe(function(value)
		table.insert(values, value)
	end))

	return values
end

describe("TransitionModel.new", function()
	it("starts hidden with hiding already complete", function()
		expect(transitionModel:IsVisible()).toBe(false)
		expect(transitionModel:IsShowingComplete()).toBe(false)
		expect(transitionModel:IsHidingComplete()).toBe(true)
	end)
end)

describe("TransitionModel.isTransitionModel", function()
	it("recognizes a transition model", function()
		expect(TransitionModel.isTransitionModel(transitionModel)).toBe(true)
	end)

	it("rejects a plain basic pane", function()
		expect(TransitionModel.isTransitionModel(maid:Add(BasicPane.new()))).toBe(false)
	end)

	it("rejects values that are not transition models", function()
		expect(TransitionModel.isTransitionModel(nil)).toBe(false)
		expect(TransitionModel.isTransitionModel({})).toBe(false)
		expect(TransitionModel.isTransitionModel(5)).toBe(false)
	end)
end)

describe("transitions without callbacks", function()
	it("completes showing immediately", function()
		local showingComplete = trackFires(transitionModel.ShowingComplete)

		transitionModel:Show()

		expect(transitionModel:IsShowingComplete()).toBe(true)
		expect(transitionModel:IsHidingComplete()).toBe(false)
		expect(showingComplete()).toBe(1)
	end)

	it("completes hiding immediately", function()
		transitionModel:Show()

		local hidingComplete = trackFires(transitionModel.HidingComplete)

		transitionModel:Hide()

		expect(transitionModel:IsHidingComplete()).toBe(true)
		expect(transitionModel:IsShowingComplete()).toBe(false)
		expect(hidingComplete()).toBe(1)
	end)

	it("does not re-run a transition set to the visibility it already has", function()
		local showingComplete = trackFires(transitionModel.ShowingComplete)

		transitionModel:Show()
		transitionModel:Show()

		expect(showingComplete()).toBe(1)
	end)
end)

describe("TransitionModel:SetPromiseShow", function()
	it("holds showing incomplete until the returned promise resolves", function()
		local callbackPromise = Promise.new()
		transitionModel:SetPromiseShow(function()
			return callbackPromise
		end)

		local showingComplete = trackFires(transitionModel.ShowingComplete)

		transitionModel:Show()
		expect(transitionModel:IsShowingComplete()).toBe(false)
		expect(showingComplete()).toBe(0)

		callbackPromise:Resolve()
		expect(transitionModel:IsShowingComplete()).toBe(true)
		expect(showingComplete()).toBe(1)
	end)

	it("passes doNotAnimate through to the callback", function()
		local observed: { boolean? } = {}
		transitionModel:SetPromiseShow(function(_callbackMaid: Maid.Maid, doNotAnimate: boolean?)
			table.insert(observed, doNotAnimate)
			return Promise.resolved()
		end)

		transitionModel:Show(true)
		transitionModel:Hide()
		transitionModel:Show()

		expect(observed[1]).toBe(true)
		expect(observed[2]).toBe(nil)
	end)

	it("cleans up the callback maid when the next transition starts", function()
		local cleaned = false
		transitionModel:SetPromiseShow(function(callbackMaid: Maid.Maid)
			callbackMaid:GiveTask(function()
				cleaned = true
			end)
			return Promise.resolved()
		end)

		transitionModel:Show()
		expect(cleaned).toBe(false)

		transitionModel:Hide()
		expect(cleaned).toBe(true)
	end)

	it("cleans up the callback maid on destroy", function()
		local cleaned = false
		transitionModel:SetPromiseShow(function(callbackMaid: Maid.Maid)
			callbackMaid:GiveTask(function()
				cleaned = true
			end)
			return Promise.new()
		end)

		transitionModel:Show()
		expect(cleaned).toBe(false)

		maid:DoCleaning()
		expect(cleaned).toBe(true)
	end)

	it("clears the callback when set to nil", function()
		transitionModel:SetPromiseShow(function()
			return Promise.new()
		end)
		transitionModel:SetPromiseShow(nil)

		transitionModel:Show()

		expect(transitionModel:IsShowingComplete()).toBe(true)
	end)

	it("rejects a callback that is not a function", function()
		expect(function()
			transitionModel:SetPromiseShow(5 :: any)
		end).toThrow()
	end)
end)

describe("TransitionModel:SetPromiseHide", function()
	it("holds hiding incomplete until the returned promise resolves", function()
		local callbackPromise = Promise.new()
		transitionModel:SetPromiseHide(function()
			return callbackPromise
		end)

		local hidingComplete = trackFires(transitionModel.HidingComplete)

		transitionModel:Show()
		transitionModel:Hide()
		expect(transitionModel:IsHidingComplete()).toBe(false)
		expect(hidingComplete()).toBe(0)

		callbackPromise:Resolve()
		expect(transitionModel:IsHidingComplete()).toBe(true)
		expect(hidingComplete()).toBe(1)
	end)

	it("abandons an in-flight hide when shown again", function()
		local callbackPromise = Promise.new()
		local cleaned = false
		transitionModel:SetPromiseHide(function(callbackMaid: Maid.Maid)
			callbackMaid:GiveTask(function()
				cleaned = true
			end)
			return callbackPromise
		end)

		transitionModel:Show()
		transitionModel:Hide()
		expect(cleaned).toBe(false)

		transitionModel:Show()
		expect(cleaned).toBe(true)

		callbackPromise:Resolve()
		expect(transitionModel:IsHidingComplete()).toBe(false)
	end)

	it("rejects a callback that is not a function", function()
		expect(function()
			transitionModel:SetPromiseHide(5 :: any)
		end).toThrow()
	end)
end)

describe("TransitionModel:PromiseShow", function()
	it("resolves once the show transition completes", function()
		local callbackPromise = Promise.new()
		transitionModel:SetPromiseShow(function()
			return callbackPromise
		end)

		local promise = maid:Add(transitionModel:PromiseShow())
		expect(transitionModel:IsVisible()).toBe(true)
		expect(promise:IsPending()).toBe(true)

		callbackPromise:Resolve()
		expect(promise:IsFulfilled()).toBe(true)
	end)

	it("resolves immediately when showing is already complete", function()
		transitionModel:Show()

		expect(transitionModel:PromiseShow():IsFulfilled()).toBe(true)
	end)

	it("rejects when hidden before showing completes", function()
		transitionModel:SetPromiseShow(function()
			return Promise.new()
		end)

		local promise = maid:Add(transitionModel:PromiseShow())
		expect(promise:IsPending()).toBe(true)

		transitionModel:Hide()
		expect(promise:IsRejected()).toBe(true)
	end)
end)

describe("TransitionModel:PromiseHide", function()
	it("resolves once the hide transition completes", function()
		local callbackPromise = Promise.new()
		transitionModel:SetPromiseHide(function()
			return callbackPromise
		end)

		transitionModel:Show()

		local promise = maid:Add(transitionModel:PromiseHide())
		expect(transitionModel:IsVisible()).toBe(false)
		expect(promise:IsPending()).toBe(true)

		callbackPromise:Resolve()
		expect(promise:IsFulfilled()).toBe(true)
	end)

	it("resolves immediately when hiding is already complete", function()
		expect(transitionModel:PromiseHide():IsFulfilled()).toBe(true)
	end)

	it("rejects when shown before hiding completes", function()
		transitionModel:SetPromiseHide(function()
			return Promise.new()
		end)

		transitionModel:Show()

		local promise = maid:Add(transitionModel:PromiseHide())
		expect(promise:IsPending()).toBe(true)

		transitionModel:Show()
		expect(promise:IsRejected()).toBe(true)
	end)
end)

describe("TransitionModel:PromiseToggle", function()
	it("runs the hide transition when visible", function()
		local shown, hidden = 0, 0
		transitionModel:SetPromiseShow(function()
			shown += 1
			return Promise.resolved()
		end)
		transitionModel:SetPromiseHide(function()
			hidden += 1
			return Promise.resolved()
		end)

		transitionModel:Show()
		expect(shown).toBe(1)

		local promise = maid:Add(transitionModel:PromiseToggle())

		expect(transitionModel:IsVisible()).toBe(false)
		expect(hidden).toBe(1)
		expect(shown).toBe(1)
		expect(transitionModel:IsHidingComplete()).toBe(true)
		expect(promise:IsFulfilled()).toBe(true)
	end)

	it("runs the show transition when hidden", function()
		local shown, hidden = 0, 0
		transitionModel:SetPromiseShow(function()
			shown += 1
			return Promise.resolved()
		end)
		transitionModel:SetPromiseHide(function()
			hidden += 1
			return Promise.resolved()
		end)

		local promise = maid:Add(transitionModel:PromiseToggle())

		expect(transitionModel:IsVisible()).toBe(true)
		expect(shown).toBe(1)
		expect(hidden).toBe(0)
		expect(transitionModel:IsShowingComplete()).toBe(true)
		expect(promise:IsFulfilled()).toBe(true)
	end)
end)

describe("TransitionModel:ObserveIsShowingComplete", function()
	it("emits the current state and each change", function()
		local values = trackValues(transitionModel:ObserveIsShowingComplete())

		transitionModel:Show()
		transitionModel:Hide()

		expect(values).toEqual({ false, true, false })
	end)
end)

describe("TransitionModel:ObserveIsHidingComplete", function()
	it("emits the current state and each change", function()
		local values = trackValues(transitionModel:ObserveIsHidingComplete())

		transitionModel:Show()
		transitionModel:Hide()

		expect(values).toEqual({ true, false, true })
	end)
end)

describe("TransitionModel:BindToPaneVisbility", function()
	it("adopts the visibility of the pane it binds to", function()
		local pane = maid:Add(BasicPane.new())
		pane:Show()

		transitionModel:BindToPaneVisbility(pane)

		expect(transitionModel:IsVisible()).toBe(true)
		expect(transitionModel:IsShowingComplete()).toBe(true)
	end)

	it("mirrors visibility in both directions", function()
		local pane = maid:Add(BasicPane.new())
		transitionModel:BindToPaneVisbility(pane)

		pane:Show()
		expect(transitionModel:IsVisible()).toBe(true)

		transitionModel:Hide()
		expect(pane:IsVisible()).toBe(false)
	end)

	it("stops mirroring once the cleanup function runs", function()
		local pane = maid:Add(BasicPane.new())
		local unbind = transitionModel:BindToPaneVisbility(pane)

		unbind()

		pane:Show()
		expect(transitionModel:IsVisible()).toBe(false)
	end)

	it("does not tear down a newer binding", function()
		local firstPane = maid:Add(BasicPane.new())
		local secondPane = maid:Add(BasicPane.new())

		local unbindFirst = transitionModel:BindToPaneVisbility(firstPane)
		transitionModel:BindToPaneVisbility(secondPane)

		unbindFirst()

		firstPane:Show()
		expect(transitionModel:IsVisible()).toBe(false)

		secondPane:Show()
		expect(transitionModel:IsVisible()).toBe(true)
	end)
end)
