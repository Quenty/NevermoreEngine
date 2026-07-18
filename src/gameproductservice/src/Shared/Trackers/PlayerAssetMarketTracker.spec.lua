--!nonstrict
--[[
	Unit coverage for PlayerAssetMarketTracker. The tracker is constructed directly with a fake
	id-conversion table and a synchronous brio observable, so no ServiceBag, GameConfig, or real
	MarketplaceService is involved. Each test builds a fresh tracker and destroys it so nothing
	leaks into the shared test place.

	@class PlayerAssetMarketTracker.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local Jest = require("Jest")
local Observable = require("Observable")
local PlayerAssetMarketTracker = require("PlayerAssetMarketTracker")
local PromiseTestUtils = require("PromiseTestUtils")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

-- Maps asset keys to numeric ids. Any key not present converts to nil, which exercises the
-- "no asset with key" reject paths.
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

-- Emits a single live brio wrapping the resolved id, synchronously on subscribe, then completes
-- for unknown keys. Synchronous emission lets ObserveAssetPurchased register the known id before
-- the test fires Purchased.
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

local function setup()
	local tracker = PlayerAssetMarketTracker.new(GameConfigAssetTypes.PRODUCT, convertIds, observeIdsBrio)

	return {
		tracker = tracker,
		destroy = function()
			tracker:Destroy()
		end,
	}
end

-- Builds a non-promptable tracker (as used for the game asset type), which should reject
-- prompts instead of surfacing them.
local function setupNonPromptable()
	local tracker = PlayerAssetMarketTracker.new(GameConfigAssetTypes.GAME, convertIds, observeIdsBrio, false)

	return {
		tracker = tracker,
		destroy = function()
			tracker:Destroy()
		end,
	}
end

-- Drives a full prompt: fires PromisePromptPurchase, waits for ShowPromptRequested to surface the
-- resolved id, then feeds the purchase result back in. Returns the tracking promise and the id.
local function promptAndCapture(tracker, idOrKey)
	local capturedId
	local conn = tracker.ShowPromptRequested:Connect(function(id)
		capturedId = id
	end)

	local promise = tracker:PromisePromptPurchase(idOrKey)
	PromiseTestUtils.awaitValue(function()
		return capturedId ~= nil
	end, 5)
	conn:Disconnect()

	return promise, capturedId
end

describe("PlayerAssetMarketTracker basics", function()
	it("should report its asset type", function()
		local context = setup()
		expect(context.tracker:GetAssetType()).toEqual(GameConfigAssetTypes.PRODUCT)
		context.destroy()
	end)

	it("should start with no prompt open", function()
		local context = setup()
		expect(context.tracker:IsPromptOpen()).toEqual(false)
		context.destroy()
	end)

	it("should hold and return an ownership tracker", function()
		local context = setup()
		expect(context.tracker:GetOwnershipTracker()).toBeNil()

		local fakeOwnershipTracker = {}
		context.tracker:SetOwnershipTracker(fakeOwnershipTracker)
		expect(context.tracker:GetOwnershipTracker()).toEqual(fakeOwnershipTracker)

		context.tracker:SetOwnershipTracker(nil)
		expect(context.tracker:GetOwnershipTracker()).toBeNil()
		context.destroy()
	end)

	it("should be promptable by default", function()
		local context = setup()
		expect(context.tracker:IsPromptable()).toEqual(true)
		context.destroy()
	end)
end)

describe("PlayerAssetMarketTracker non-promptable asset types", function()
	it("should report IsPromptable() as false", function()
		local context = setupNonPromptable()
		expect(context.tracker:IsPromptable()).toEqual(false)
		context.destroy()
	end)

	it("should reject PromisePromptPurchase for a known id without opening a prompt", function()
		local context = setupNonPromptable()

		local promptRequested = false
		local conn = context.tracker.ShowPromptRequested:Connect(function()
			promptRequested = true
		end)

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromisePromptPurchase("swordKey"), 5)
		conn:Disconnect()

		expect(outcome).toEqual("rejected")
		expect(promptRequested).toEqual(false)
		expect(context.tracker:IsPromptOpen()).toEqual(false)
		context.destroy()
	end)

	it("should reject PromisePromptPurchase for an unknown key too", function()
		local context = setupNonPromptable()

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromisePromptPurchase("doesNotExist"), 5)
		expect(outcome).toEqual("rejected")
		context.destroy()
	end)
end)

describe("PlayerAssetMarketTracker:HasPurchasedThisSession()", function()
	it("should return false before anything is purchased", function()
		local context = setup()
		expect(context.tracker:HasPurchasedThisSession("swordKey")).toEqual(false)
		context.destroy()
	end)

	it("should return true after a purchase event for that id", function()
		local context = setup()
		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, true)
		expect(context.tracker:HasPurchasedThisSession("swordKey")).toEqual(true)
		context.destroy()
	end)

	it("should stay false for a different id than the one purchased", function()
		local context = setup()
		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, true)
		expect(context.tracker:HasPurchasedThisSession("shieldKey")).toEqual(false)
		context.destroy()
	end)

	it("should return false for an unknown key", function()
		local context = setup()
		expect(context.tracker:HasPurchasedThisSession("doesNotExist")).toEqual(false)
		context.destroy()
	end)

	it("should not mark a failed purchase as purchased", function()
		local context = setup()
		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, false)
		expect(context.tracker:HasPurchasedThisSession("swordKey")).toEqual(false)
		context.destroy()
	end)
end)

describe("PlayerAssetMarketTracker:HandlePurchaseEvent()", function()
	it("should fire the Purchased signal with the id on a successful purchase", function()
		local context = setup()

		local fired = {}
		local conn = context.tracker.Purchased:Connect(function(id)
			table.insert(fired, id)
		end)

		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, true)
		conn:Disconnect()

		expect(#fired).toEqual(1)
		expect(fired[1]).toEqual(KEY_TO_ID.swordKey)
		context.destroy()
	end)

	it("should not fire Purchased on a failed purchase", function()
		local context = setup()

		local firedCount = 0
		local conn = context.tracker.Purchased:Connect(function()
			firedCount += 1
		end)

		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, false)
		conn:Disconnect()

		expect(firedCount).toEqual(0)
		context.destroy()
	end)
end)

describe("PlayerAssetMarketTracker:PromisePromptPurchase()", function()
	it("should reject for an unknown key", function()
		local context = setup()

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromisePromptPurchase("doesNotExist"), 5)
		expect(outcome).toEqual("rejected")
		context.destroy()
	end)

	it("should request a prompt and resolve true once the purchase succeeds", function()
		local context = setup()

		local promise, capturedId = promptAndCapture(context.tracker, "swordKey")
		expect(capturedId).toEqual(KEY_TO_ID.swordKey)
		expect(context.tracker:IsPromptOpen()).toEqual(true)

		context.tracker:HandlePurchaseEvent(capturedId, true)
		context.tracker:HandlePromptClosedEvent(capturedId)

		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local ok, purchased = promise:Yield()
		expect(ok).toEqual(true)
		expect(purchased).toEqual(true)
		context.destroy()
	end)

	it("should resolve false when the purchase is declined", function()
		local context = setup()

		local promise, capturedId = promptAndCapture(context.tracker, "swordKey")
		context.tracker:HandlePurchaseEvent(capturedId, false)
		context.tracker:HandlePromptClosedEvent(capturedId)

		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local ok, purchased = promise:Yield()
		expect(ok).toEqual(true)
		expect(purchased).toEqual(false)
		context.destroy()
	end)

	it("should reject a second prompt while one is already open", function()
		local context = setup()

		local firstPromise, firstId = promptAndCapture(context.tracker, "swordKey")
		expect(context.tracker:IsPromptOpen()).toEqual(true)

		local secondOutcome = PromiseTestUtils.awaitOutcome(context.tracker:PromisePromptPurchase("shieldKey"), 5)
		expect(secondOutcome).toEqual("rejected")

		-- Close out the first prompt so nothing leaks.
		context.tracker:HandlePurchaseEvent(firstId, true)
		context.tracker:HandlePromptClosedEvent(firstId)
		PromiseTestUtils.awaitSettled(firstPromise, 5)
		context.destroy()
	end)
end)

describe("PlayerAssetMarketTracker prompt open counting", function()
	it("should report the prompt closed after HandlePromptClosedEvent", function()
		local context = setup()

		local promise, capturedId = promptAndCapture(context.tracker, "swordKey")
		expect(context.tracker:IsPromptOpen()).toEqual(true)

		context.tracker:HandlePurchaseEvent(capturedId, true)
		context.tracker:HandlePromptClosedEvent(capturedId)
		PromiseTestUtils.awaitSettled(promise, 5)

		expect(PromiseTestUtils.awaitValue(function()
			return not context.tracker:IsPromptOpen()
		end, 5)).toEqual(true)
		context.destroy()
	end)

	it("should surface the open count through ObservePromptOpenCount", function()
		local context = setup()

		local counts = {}
		local sub = context.tracker:ObservePromptOpenCount():Subscribe(function(value)
			table.insert(counts, value)
		end)

		local promise, capturedId = promptAndCapture(context.tracker, "swordKey")
		context.tracker:HandlePurchaseEvent(capturedId, true)
		context.tracker:HandlePromptClosedEvent(capturedId)
		PromiseTestUtils.awaitSettled(promise, 5)
		sub:Destroy()

		-- Should have observed the initial 0 and at least one increment to 1.
		expect(counts[1]).toEqual(0)
		local sawOpen = false
		for _, value in counts do
			if value >= 1 then
				sawOpen = true
			end
		end
		expect(sawOpen).toEqual(true)
		context.destroy()
	end)
end)

describe("PlayerAssetMarketTracker:ObserveAssetPurchased()", function()
	it("should fire when the tracked id is purchased", function()
		local context = setup()

		local fireCount = 0
		local sub = context.tracker:ObserveAssetPurchased("swordKey"):Subscribe(function()
			fireCount += 1
		end)

		context.tracker:HandlePurchaseEvent(KEY_TO_ID.swordKey, true)

		expect(PromiseTestUtils.awaitValue(function()
			return fireCount > 0
		end, 5)).toEqual(true)
		sub:Destroy()
		context.destroy()
	end)

	it("should not fire when a different id is purchased", function()
		local context = setup()

		local fireCount = 0
		local sub = context.tracker:ObserveAssetPurchased("swordKey"):Subscribe(function()
			fireCount += 1
		end)

		context.tracker:HandlePurchaseEvent(KEY_TO_ID.shieldKey, true)
		task.wait()
		sub:Destroy()

		expect(fireCount).toEqual(0)
		context.destroy()
	end)
end)
