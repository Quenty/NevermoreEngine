--!strict
--[[
	Unit coverage for PlayerAssetOwnershipTracker. The tracker is constructed directly with a fake
	config picker (key -> id lookup) and a fake market tracker exposing only a Purchased signal, so
	no ServiceBag, GameConfig, or real MarketplaceService is involved. A PlayerMock stands in for
	the player because the tracker only stores the player, never reads properties off it in the code
	paths under test.

	@class PlayerAssetOwnershipTracker.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigPicker = require("GameConfigPicker")
local Jest = require("Jest")
local JestUtils = require("JestUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableSpy = require("ObservableSpy")
local PlayerAssetOwnershipTracker = require("PlayerAssetOwnershipTracker")
local PlayerMock = require("PlayerMock")
local PlayerProductOwnershipOverrideUtils = require("PlayerProductOwnershipOverrideUtils")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local RxTestUtils = require("RxTestUtils")
local Signal = require("Signal")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local KEY_TO_ID = {
	swordKey = 111,
	shieldKey = 222,
}

local function toId(idOrKey)
	if type(idOrKey) == "number" then
		return idOrKey
	end
	return KEY_TO_ID[idOrKey]
end

local function makeConfigPicker()
	return {
		ToAssetId = function(_self, _assetType, idOrKey)
			return toId(idOrKey)
		end,
		ObserveToAssetIdBrio = function(_self, _assetType, idOrKey)
			return Observable.new(function(sub)
				local id = toId(idOrKey)
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
		end,
	}
end

local function setup()
	local maid = Maid.new()

	local purchased = Signal.new()
	local marketTracker = { Purchased = purchased }
	local player = PlayerMock.new()
	player.Name = "FakePlayer"

	local tracker = PlayerAssetOwnershipTracker.new(
		(player :: any) :: Player,
		(makeConfigPicker() :: any) :: GameConfigPicker.GameConfigPicker,
		GameConfigAssetTypes.PASS,
		marketTracker
	)

	maid:GiveTask(function()
		tracker:Destroy()
		purchased:Destroy()
		player:Destroy()
	end)

	local controller = {
		maid = maid,
		tracker = tracker,
		marketTracker = marketTracker,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller))

	return controller
end

describe("PlayerAssetOwnershipTracker:PromiseOwnsAsset()", function()
	it("should reject for an unknown key", function()
		local context = setup()

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromiseOwnsAsset("doesNotExist"), 5)
		expect(outcome).toEqual("rejected")
		context:Destroy()
	end)

	it("should reject when no ownership callback is set and the asset is not already owned", function()
		local context = setup()

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(outcome).toEqual("rejected")
		context:Destroy()
	end)

	it("should resolve true when the callback reports ownership", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(true)
		end)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(true)
		context:Destroy()
	end)

	it("should resolve false when the callback reports no ownership", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(false)
		context:Destroy()
	end)

	it("should cache the callback result and not query twice", function()
		local context = setup()

		local callCount = 0
		context.tracker:SetQueryOwnershipCallback(function()
			callCount += 1
			return Promise.resolved(true)
		end)

		PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"))
		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"))

		expect(callCount).toEqual(1)
		expect(owns).toEqual(true)
		context:Destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:SetOwnership()", function()
	it("should mark an asset owned so PromiseOwnsAsset resolves true without a callback", function()
		local context = setup()

		context.tracker:SetOwnership(KEY_TO_ID.swordKey, true)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(true)
		context:Destroy()
	end)

	it("should ignore an unknown key without erroring", function()
		local context = setup()
		context.tracker:SetOwnership("doesNotExist", true)
		context:Destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker market tracker integration", function()
	it("should mark ownership when the market tracker fires Purchased", function()
		local context = setup()

		context.marketTracker.Purchased:Fire(KEY_TO_ID.swordKey)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(true)
		context:Destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:SetQueryOwnershipCallback()", function()
	it("should clear the cache so a new callback is consulted", function()
		local context = setup()

		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)
		expect(PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"))).toEqual(false)

		local secondCallbackCalls = 0
		context.tracker:SetQueryOwnershipCallback(function()
			secondCallbackCalls += 1
			return Promise.resolved(true)
		end)

		local secondOwns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"))
		expect(secondCallbackCalls).toEqual(1)
		expect(secondOwns).toEqual(true)
		context:Destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:ObserveOwnsAsset()", function()
	it("should emit false, then true once ownership is set", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		local values = ObservableSpy.new(context.tracker:ObserveOwnsAsset(KEY_TO_ID.swordKey))

		expect(#values >= 1).toBe(true)
		expect(values[1]).toEqual(false)

		context.tracker:SetOwnership(KEY_TO_ID.swordKey, true)

		expect(values[#values]).toBe(true)
		values:Destroy()
		context:Destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:SetOwnershipOverride() ownership wins", function()
	it("should resolve true for a true override even when the callback reports no ownership", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		context.tracker:SetOwnershipOverride("swordKey", true)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(true)
		context:Destroy()
	end)

	it("should resolve false for a false override even when the callback reports ownership", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(true)
		end)

		context.tracker:SetOwnershipOverride("swordKey", false)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(false)
		context:Destroy()
	end)

	it("should resolve true for a true override even with no callback set", function()
		local context = setup()

		context.tracker:SetOwnershipOverride("swordKey", true)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(true)
		context:Destroy()
	end)

	it("should let a false override revoke an asset already in the owned set", function()
		local context = setup()
		context.tracker:SetOwnership(KEY_TO_ID.swordKey, true)

		context.tracker:SetOwnershipOverride("swordKey", false)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(false)
		context:Destroy()
	end)

	it("should let a false override revoke an asset after a purchase fires", function()
		local context = setup()
		context.marketTracker.Purchased:Fire(KEY_TO_ID.swordKey)

		context.tracker:SetOwnershipOverride(KEY_TO_ID.swordKey, false)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(false)
		context:Destroy()
	end)

	it("should not invoke the cloud callback while an override is set", function()
		local context = setup()

		local callCount = 0
		context.tracker:SetQueryOwnershipCallback(function()
			callCount += 1
			return Promise.resolved(true)
		end)

		context.tracker:SetOwnershipOverride("swordKey", true)
		expect(PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"))).toEqual(true)

		expect(callCount).toEqual(0)
		context:Destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:SetOwnershipOverride() lifecycle", function()
	it("should fall back to the cloud query once the override is cleared", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		context.tracker:SetOwnershipOverride("swordKey", true)
		local ownsWhileOverridden = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(ownsWhileOverridden).toEqual(true)

		context.tracker:ClearOwnershipOverride("swordKey")
		local ownsAfterClear = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(ownsAfterClear).toEqual(false)
		context:Destroy()
	end)

	it("should treat SetOwnershipOverride(nil) as clearing the override", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		context.tracker:SetOwnershipOverride("swordKey", true)
		context.tracker:SetOwnershipOverride("swordKey", nil)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(false)
		context:Destroy()
	end)

	it("should flip when the override is re-set", function()
		local context = setup()

		context.tracker:SetOwnershipOverride("swordKey", true)
		expect(PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"))).toEqual(true)

		context.tracker:SetOwnershipOverride("swordKey", false)
		expect(PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"))).toEqual(false)
		context:Destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:SetOwnershipOverride() combined keys", function()
	it("should honor an override set by key when queried by id", function()
		local context = setup()

		context.tracker:SetOwnershipOverride("swordKey", true)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset(KEY_TO_ID.swordKey), 5)
		expect(owns).toEqual(true)
		context:Destroy()
	end)

	it("should honor an override set by id when queried by key", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(true)
		end)

		context.tracker:SetOwnershipOverride(KEY_TO_ID.swordKey, false)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(false)
		context:Destroy()
	end)

	it("should not affect a different asset", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		context.tracker:SetOwnershipOverride("swordKey", true)

		local owns = PromiseTestUtils.awaitFulfilled(context.tracker:PromiseOwnsAsset("shieldKey"), 5)
		expect(owns).toEqual(false)
		context:Destroy()
	end)

	it("should ignore an override for an unknown key without erroring", function()
		local context = setup()
		context.tracker:SetOwnershipOverride("doesNotExist", true)

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromiseOwnsAsset("doesNotExist"), 5)
		expect(outcome).toEqual("rejected")
		context:Destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker query failures", function()
	--[[
		Both seams the tracker handles a failure through, counted rather than watched: `warn` cannot be
		intercepted from here, and an unhandled rejection announces itself in the log rather than to the
		test. So the claim is pinned structurally -- the failure is reported once at the query, and every
		subscriber's continuation is consumed -- which is exactly what deleting either handler undoes.

		Spied on the class, so an instance built inside `func` is already covered. Restored through
		afterThis: a test killed mid-yield would otherwise leave the recorder installed for the whole run.
	]]
	local trackerClass: any = PlayerAssetOwnershipTracker
	local realWarn = trackerClass._warnQueryFailed
	local realConsume = trackerClass._consumeObservedQueryFailure

	local reports: { any } = {}
	local consumed: { any } = {}

	local function recordFailureHandling(): ()
		table.clear(reports)
		table.clear(consumed)

		trackerClass._warnQueryFailed = function(_self, assetId, err)
			table.insert(reports, { assetId = assetId, err = err })
		end
		trackerClass._consumeObservedQueryFailure = function(_self, err)
			table.insert(consumed, err)
		end

		JestUtils.afterThis(function()
			trackerClass._warnQueryFailed = realWarn
			trackerClass._consumeObservedQueryFailure = realConsume
		end)
	end

	it("should report once at the query and consume every subscriber's copy", function()
		local context = setup()
		recordFailureHandling()

		-- Pending until we say otherwise, which is the shape the live failure had: a marketplace call
		-- still out when the subscribers attach. An already-rejected promise would let Then hand back the
		-- parent instead of a child, so no consumer would have a rejection to leave unhandled and the
		-- test would pass with the handlers deleted.
		local pending = Promise.new()
		context.tracker:SetQueryOwnershipCallback(function()
			return pending
		end)

		local emitted = {}
		for _ = 1, 3 do
			table.insert(
				emitted,
				RxTestUtils.collectList(context.maid, context.tracker:ObserveOwnsAsset(KEY_TO_ID.swordKey))
			)
		end

		local asked = context.tracker:PromiseOwnsAsset("swordKey")
		pending:Reject("cloud refused")

		PromiseTestUtils.awaitRejected(asked)

		expect(#consumed >= 3).toBe(true)

		-- One report for the query, one consumption per subscriber.
		expect(#reports).toEqual(1)
		expect(reports[1].assetId).toEqual(KEY_TO_ID.swordKey)
		expect(reports[1].err).toEqual("cloud refused")
		expect(#consumed).toEqual(3)

		-- An unresolvable asset emits nothing at all: silence reads as unresolved, where `false` would
		-- read as "does not own it" and turn a failed lookup into a refusal.
		expect(emitted).toEqual({ {}, {}, {} })

		context:Destroy()
	end)

	it("should not report an asset it was never given a callback to query", function()
		local context = setup()
		recordFailureHandling()

		-- No callback set: this realm cannot ask, rather than having asked and failed, so the rejection
		-- explains itself and nothing is reported.
		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(outcome).toEqual("rejected")

		expect(#reports).toEqual(0)
		context:Destroy()
	end)

	it("should not report a query cancelled by teardown as a failure", function()
		local context = setup()
		recordFailureHandling()

		local pending = Promise.new()
		context.tracker:SetQueryOwnershipCallback(function()
			return pending
		end)

		local asked = context.tracker:PromiseOwnsAsset("swordKey")

		-- Destroying the tracker rejects the query with nothing, which is teardown rather than a refusal.
		-- The real _warnQueryFailed drops it on the nil check; here we see it arrive and assert the shape.
		context:Destroy()
		PromiseTestUtils.awaitRejected(asked, 5)

		for _, report in reports do
			expect(report.err).toEqual(nil)
		end

		pending:Destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:ObserveOwnsAsset() overrides", function()
	it("should emit the override value and revert to the cloud query when cleared", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		local values = ObservableSpy.new(context.tracker:ObserveOwnsAsset(KEY_TO_ID.swordKey))

		expect(values[#values]).toBe(false)

		context.tracker:SetOwnershipOverride(KEY_TO_ID.swordKey, true)
		expect(values[#values]).toBe(true)

		context.tracker:ClearOwnershipOverride(KEY_TO_ID.swordKey)
		expect(values[#values]).toBe(false)

		values:Destroy()
		context:Destroy()
	end)

	it("should emit false for a false override even when the cloud query reports ownership", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(true)
		end)

		context.tracker:SetOwnershipOverride(KEY_TO_ID.swordKey, false)

		local values = ObservableSpy.new(context.tracker:ObserveOwnsAsset(KEY_TO_ID.swordKey))

		expect(values[#values]).toBe(false)

		values:Destroy()
		context:Destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker override replication", function()
	-- Two trackers over the SAME player share the replicated attribute. Roblox attribute
	-- replication means a client sees exactly the attribute the server wrote, so a second tracker
	-- binding to the same player is the replication-receive path.
	local ATTRIBUTE_NAME = PlayerProductOwnershipOverrideUtils.attributeName(GameConfigAssetTypes.PASS)

	local function makeTracker(player: Instance)
		local purchased = Signal.new()
		local tracker = PlayerAssetOwnershipTracker.new(
			(player :: any) :: Player,
			(makeConfigPicker() :: any) :: GameConfigPicker.GameConfigPicker,
			GameConfigAssetTypes.PASS,
			{ Purchased = purchased }
		)
		return tracker, function()
			tracker:Destroy()
			purchased:Destroy()
		end
	end

	it("should apply an override already present when a new tracker binds to the same player", function()
		local player = PlayerMock.new()

		local serverTracker, destroyServer = makeTracker(player)
		serverTracker:SetOwnershipOverride("swordKey", true)

		local clientTracker, destroyClient = makeTracker(player)
		local owns = PromiseTestUtils.awaitFulfilled(clientTracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(true)

		destroyClient()
		destroyServer()
		player:Destroy()
	end)

	it("should apply a false override present at bind time even when the cloud query owns", function()
		local player = PlayerMock.new()

		local serverTracker, destroyServer = makeTracker(player)
		serverTracker:SetOwnershipOverride("swordKey", false)

		local clientTracker, destroyClient = makeTracker(player)
		clientTracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(true)
		end)
		local owns = PromiseTestUtils.awaitFulfilled(clientTracker:PromiseOwnsAsset("swordKey"), 5)
		expect(owns).toEqual(false)

		destroyClient()
		destroyServer()
		player:Destroy()
	end)

	it("should not write the attribute for an unknown key", function()
		local player = PlayerMock.new()
		local tracker, destroy = makeTracker(player)

		tracker:SetOwnershipOverride("doesNotExist", true)
		expect(player:GetAttribute(ATTRIBUTE_NAME)).toEqual(nil)

		destroy()
		player:Destroy()
	end)

	it("should remove the attribute once the only override is cleared", function()
		local player = PlayerMock.new()
		local tracker, destroy = makeTracker(player)

		tracker:SetOwnershipOverride("swordKey", true)
		expect(player:GetAttribute(ATTRIBUTE_NAME) == nil).toEqual(false)

		tracker:ClearOwnershipOverride("swordKey")
		expect(player:GetAttribute(ATTRIBUTE_NAME)).toEqual(nil)

		destroy()
		player:Destroy()
	end)
end)
