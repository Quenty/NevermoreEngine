--!strict
--[[
	Unit coverage for PlayerAssetMarketTracker. The tracker is constructed directly with a fake
	id-conversion table and a synchronous brio observable, so no ServiceBag, GameConfig, or real
	MarketplaceService is involved.

	@class PlayerAssetMarketTracker.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSpy = require("ObservableSpy")
local PlayerAssetMarketTracker = require("PlayerAssetMarketTracker")
local PromiseTestUtils = require("PromiseTestUtils")
local SignalTestUtils = require("SignalTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local KEY_TO_ID = {
	swordKey = 111,
	shieldKey = 222,
}

local function convertIds(idOrKey)
	if type(idOrKey) == "number" then
		return idOrKey
	end
	return KEY_TO_ID[idOrKey]
end

local function observeIdsBrio(idOrKey)
	return Observable.new(function(sub)
		local id = convertIds(idOrKey)
		if not id then
			sub:Complete()
			return nil
		end

		local brio = Brio.new(id)
		sub:Fire(brio)

		return function()
			brio:Destroy()
		end
	end)
end

type Controller = {
	maid: Maid.Maid,
	tracker: PlayerAssetMarketTracker.PlayerAssetMarketTracker,
	Destroy: (self: Controller) -> (),
}

local function setup(): Controller
	local maid = Maid.new()
	local tracker = PlayerAssetMarketTracker.new(GameConfigAssetTypes.PRODUCT, convertIds, observeIdsBrio)
	maid:GiveTask(tracker)

	local controller: Controller = {
		maid = maid,
		tracker = tracker,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

local function setupNonPromptable(): Controller
	local maid = Maid.new()
	local tracker = PlayerAssetMarketTracker.new(GameConfigAssetTypes.GAME, convertIds, observeIdsBrio, false)
	maid:GiveTask(tracker)

	local controller: Controller = {
		maid = maid,
		tracker = tracker,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

local function promptAndCapture(context: Controller, idOrKey: string | number)
	local requestedIds = SignalTestUtils.collectFireList(context.maid, context.tracker.ShowPromptRequested)

	local promise = context.tracker:PromisePromptPurchase(idOrKey)
	expect(requestedIds[1]).never.toBeNil()

	return promise, requestedIds[1]
end

describe("PlayerAssetMarketTracker basics", function()
	it("should report its asset type", function()
		local context = setup()
		expect(context.tracker:GetAssetType()).toEqual(GameConfigAssetTypes.PRODUCT)
		context:Destroy()
	end)

	it("should start with no prompt open", function()
		local context = setup()
		expect(context.tracker:IsPromptOpen()).toEqual(false)
		context:Destroy()
	end)

	it("should hold and return an ownership tracker", function()
		local context = setup()
		expect(context.tracker:GetOwnershipTracker()).toBeNil()

		local fakeOwnershipTracker = {}
		context.tracker:SetOwnershipTracker(fakeOwnershipTracker :: any)
		expect(context.tracker:GetOwnershipTracker()).toEqual(fakeOwnershipTracker)

		context.tracker:SetOwnershipTracker(nil)
		expect(context.tracker:GetOwnershipTracker()).toBeNil()
		context:Destroy()
	end)

	it("should be promptable by default", function()
		local context = setup()
		expect(context.tracker:IsPromptable()).toEqual(true)
		context:Destroy()
	end)
end)

describe("PlayerAssetMarketTracker non-promptable asset types", function()
	it("should report IsPromptable() as false", function()
		local context = setupNonPromptable()
		expect(context.tracker:IsPromptable()).toEqual(false)
		context:Destroy()
	end)

	it("should reject PromisePromptPurchase for a known id without opening a prompt", function()
		local context = setupNonPromptable()

		local promptRequested = SignalTestUtils.countFires(context.maid, context.tracker.ShowPromptRequested)

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromisePromptPurchase("swordKey"), 5)

		expect(outcome).toEqual("rejected")
		expect(promptRequested()).toEqual(0)
		expect(context.tracker:IsPromptOpen()).toEqual(false)
		context:Destroy()
	end)

	it("should reject PromisePromptPurchase for an unknown key too", function()
		local context = setupNonPromptable()

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromisePromptPurchase("doesNotExist"), 5)
		expect(outcome).toEqual("rejected")
		context:Destroy()
	end)
end)

describe("PlayerAssetMarketTracker:HasPurchasedThisSession()", function()
	it("should return false before anything is purchased", function()
		local context = setup()
		expect(context.tracker:HasPurchasedThisSession("swordKey")).toEqual(false)
		context:Destroy()
	end)

	it("should return true after a purchase event for that id", function()
		local context = setup()
		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, true)
		expect(context.tracker:HasPurchasedThisSession("swordKey")).toEqual(true)
		context:Destroy()
	end)

	it("should stay false for a different id than the one purchased", function()
		local context = setup()
		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, true)
		expect(context.tracker:HasPurchasedThisSession("shieldKey")).toEqual(false)
		context:Destroy()
	end)

	it("should return false for an unknown key", function()
		local context = setup()
		expect(context.tracker:HasPurchasedThisSession("doesNotExist")).toEqual(false)
		context:Destroy()
	end)

	it("should not mark a failed purchase as purchased", function()
		local context = setup()
		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, false)
		expect(context.tracker:HasPurchasedThisSession("swordKey")).toEqual(false)
		context:Destroy()
	end)
end)

describe("PlayerAssetMarketTracker:HandlePurchaseEvent()", function()
	it("should fire the Purchased signal with the id on a successful purchase", function()
		local context = setup()

		local fired = SignalTestUtils.collectFireList(context.maid, context.tracker.Purchased)

		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, true)

		expect(#fired).toEqual(1)
		expect(fired[1]).toEqual(KEY_TO_ID.swordKey)
		context:Destroy()
	end)

	it("should not fire Purchased on a failed purchase", function()
		local context = setup()

		local firedCount = SignalTestUtils.countFires(context.maid, context.tracker.Purchased)

		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, false)

		expect(firedCount()).toEqual(0)
		context:Destroy()
	end)
end)

describe("PlayerAssetMarketTracker:PromisePromptPurchase()", function()
	it("should reject for an unknown key", function()
		local context = setup()

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromisePromptPurchase("doesNotExist"), 5)
		expect(outcome).toEqual("rejected")
		context:Destroy()
	end)

	it("should request a prompt and resolve true once the purchase succeeds", function()
		local context = setup()

		local promise, capturedId = promptAndCapture(context, "swordKey")
		expect(capturedId).toEqual(KEY_TO_ID.swordKey)
		expect(context.tracker:IsPromptOpen()).toEqual(true)

		context.tracker:HandlePurchaseEvent(capturedId, true)
		context.tracker:HandlePromptClosedEvent(capturedId)

		local purchased = PromiseTestUtils.awaitFulfilled(promise, 5)
		expect(purchased).toEqual(true)
		context:Destroy()
	end)

	it("should resolve false when the purchase is declined", function()
		local context = setup()

		local promise, capturedId = promptAndCapture(context, "swordKey")
		context.tracker:HandlePurchaseEvent(capturedId, false)
		context.tracker:HandlePromptClosedEvent(capturedId)

		local purchased = PromiseTestUtils.awaitFulfilled(promise, 5)
		expect(purchased).toEqual(false)
		context:Destroy()
	end)

	it("should reject a second prompt while one is already open", function()
		local context = setup()

		local firstPromise, firstId = promptAndCapture(context, "swordKey")
		expect(context.tracker:IsPromptOpen()).toEqual(true)

		local secondOutcome = PromiseTestUtils.awaitOutcome(context.tracker:PromisePromptPurchase("shieldKey"), 5)
		expect(secondOutcome).toEqual("rejected")

		context.tracker:HandlePurchaseEvent(firstId, true)
		context.tracker:HandlePromptClosedEvent(firstId)
		PromiseTestUtils.awaitFulfilled(firstPromise)
		context:Destroy()
	end)
end)

describe("PlayerAssetMarketTracker prompt open counting", function()
	it("should report the prompt closed after HandlePromptClosedEvent", function()
		local context = setup()

		local promise, capturedId = promptAndCapture(context, "swordKey")
		expect(context.tracker:IsPromptOpen()).toEqual(true)

		context.tracker:HandlePurchaseEvent(capturedId, true)
		context.tracker:HandlePromptClosedEvent(capturedId)
		PromiseTestUtils.awaitFulfilled(promise)

		expect(not context.tracker:IsPromptOpen()).toBe(true)
		context:Destroy()
	end)

	it("should surface the open count through ObservePromptOpenCount", function()
		local context = setup()

		local counts = ObservableSpy.new(context.tracker:ObservePromptOpenCount())

		local promise, capturedId = promptAndCapture(context, "swordKey")
		context.tracker:HandlePurchaseEvent(capturedId, true)
		context.tracker:HandlePromptClosedEvent(capturedId)
		PromiseTestUtils.awaitFulfilled(promise)
		counts:Destroy()

		expect(counts[1]).toEqual(0)
		local sawOpen = false
		for _, value in counts do
			if value >= 1 then
				sawOpen = true
			end
		end
		expect(sawOpen).toEqual(true)
		context:Destroy()
	end)
end)

describe("PlayerAssetMarketTracker:ObserveAssetPurchased()", function()
	it("should fire when the tracked id is purchased", function()
		local context = setup()

		local emissions = ObservableSpy.new(context.tracker:ObserveAssetPurchased("swordKey") :: any)

		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, true)

		expect(#emissions > 0).toBe(true)
		emissions:Destroy()
		context:Destroy()
	end)

	it("should not fire when a different id is purchased", function()
		local context = setup()

		local emissions = ObservableSpy.new(context.tracker:ObserveAssetPurchased("swordKey") :: any)

		context.tracker:HandlePurchaseEvent(KEY_TO_ID.shieldKey, true)
		emissions:Destroy()

		expect(#emissions).toEqual(0)
		context:Destroy()
	end)
end)
