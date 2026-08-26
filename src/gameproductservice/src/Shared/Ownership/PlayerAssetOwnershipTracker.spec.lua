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
local PlayerAssetOwnershipTracker = require("PlayerAssetOwnershipTracker")
local PlayerMock = require("PlayerMock")
local PlayerProductOwnershipOverrideUtils = require("PlayerProductOwnershipOverrideUtils")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
local Signal = require("Signal")

local afterEach = Jest.Globals.afterEach
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
		tracker = tracker,
		marketTracker = marketTracker,
		destroy = function()
			maid:DoCleaning()
		end,
	}

	maid:GiveTask(JestUtils.afterThis(controller.destroy))

	return controller
end

describe("PlayerAssetOwnershipTracker:PromiseOwnsAsset()", function()
	it("should reject for an unknown key", function()
		local context = setup()

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromiseOwnsAsset("doesNotExist"), 5)
		expect(outcome).toEqual("rejected")
		context.destroy()
	end)

	it("should reject when no ownership callback is set and the asset is not already owned", function()
		local context = setup()

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(outcome).toEqual("rejected")
		context.destroy()
	end)

	it("should resolve true when the callback reports ownership", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(true)
		end)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local ok, owns = promise:Yield()
		expect(ok).toEqual(true)
		expect(owns).toEqual(true)
		context.destroy()
	end)

	it("should resolve false when the callback reports no ownership", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local ok, owns = promise:Yield()
		expect(ok).toEqual(true)
		expect(owns).toEqual(false)
		context.destroy()
	end)

	it("should cache the callback result and not query twice", function()
		local context = setup()

		local callCount = 0
		context.tracker:SetQueryOwnershipCallback(function()
			callCount += 1
			return Promise.resolved(true)
		end)

		local first = context.tracker:PromiseOwnsAsset("swordKey")
		PromiseTestUtils.awaitSettled(first, 5)
		local second = context.tracker:PromiseOwnsAsset("swordKey")
		PromiseTestUtils.awaitSettled(second, 5)

		expect(callCount).toEqual(1)
		local _, owns = second:Yield()
		expect(owns).toEqual(true)
		context.destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:SetOwnership()", function()
	it("should mark an asset owned so PromiseOwnsAsset resolves true without a callback", function()
		local context = setup()

		context.tracker:SetOwnership(KEY_TO_ID.swordKey, true)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(true)
		context.destroy()
	end)

	it("should ignore an unknown key without erroring", function()
		local context = setup()
		context.tracker:SetOwnership("doesNotExist", true)
		context.destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker market tracker integration", function()
	it("should mark ownership when the market tracker fires Purchased", function()
		local context = setup()

		context.marketTracker.Purchased:Fire(KEY_TO_ID.swordKey)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(true)
		context.destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:SetQueryOwnershipCallback()", function()
	it("should clear the cache so a new callback is consulted", function()
		local context = setup()

		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)
		local first = context.tracker:PromiseOwnsAsset("swordKey")
		PromiseTestUtils.awaitSettled(first, 5)
		local _, firstOwns = first:Yield()
		expect(firstOwns).toEqual(false)

		local secondCallbackCalls = 0
		context.tracker:SetQueryOwnershipCallback(function()
			secondCallbackCalls += 1
			return Promise.resolved(true)
		end)

		local second = context.tracker:PromiseOwnsAsset("swordKey")
		PromiseTestUtils.awaitSettled(second, 5)
		expect(secondCallbackCalls).toEqual(1)
		local _, secondOwns = second:Yield()
		expect(secondOwns).toEqual(true)
		context.destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:ObserveOwnsAsset()", function()
	it("should emit false, then true once ownership is set", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		local values = {}
		local sub = context.tracker:ObserveOwnsAsset(KEY_TO_ID.swordKey):Subscribe(function(value)
			table.insert(values, value)
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return #values >= 1
		end, 5)).toEqual(true)
		expect(values[1]).toEqual(false)

		context.tracker:SetOwnership(KEY_TO_ID.swordKey, true)

		expect(PromiseTestUtils.awaitValue(function()
			return values[#values] == true
		end, 5)).toEqual(true)
		sub:Destroy()
		context.destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:SetOwnershipOverride() ownership wins", function()
	it("should resolve true for a true override even when the callback reports no ownership", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		context.tracker:SetOwnershipOverride("swordKey", true)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(true)
		context.destroy()
	end)

	it("should resolve false for a false override even when the callback reports ownership", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(true)
		end)

		context.tracker:SetOwnershipOverride("swordKey", false)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(false)
		context.destroy()
	end)

	it("should resolve true for a true override even with no callback set", function()
		local context = setup()

		context.tracker:SetOwnershipOverride("swordKey", true)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(true)
		context.destroy()
	end)

	it("should let a false override revoke an asset already in the owned set", function()
		local context = setup()
		context.tracker:SetOwnership(KEY_TO_ID.swordKey, true)

		context.tracker:SetOwnershipOverride("swordKey", false)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(false)
		context.destroy()
	end)

	it("should let a false override revoke an asset after a purchase fires", function()
		local context = setup()
		context.marketTracker.Purchased:Fire(KEY_TO_ID.swordKey)

		context.tracker:SetOwnershipOverride(KEY_TO_ID.swordKey, false)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(false)
		context.destroy()
	end)

	it("should not invoke the cloud callback while an override is set", function()
		local context = setup()

		local callCount = 0
		context.tracker:SetQueryOwnershipCallback(function()
			callCount += 1
			return Promise.resolved(true)
		end)

		context.tracker:SetOwnershipOverride("swordKey", true)
		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		PromiseTestUtils.awaitSettled(promise, 5)

		expect(callCount).toEqual(0)
		context.destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:SetOwnershipOverride() lifecycle", function()
	it("should fall back to the cloud query once the override is cleared", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		context.tracker:SetOwnershipOverride("swordKey", true)
		local owned = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(owned, 5)).toEqual(true)
		local _, ownsWhileOverridden = owned:Yield()
		expect(ownsWhileOverridden).toEqual(true)

		context.tracker:ClearOwnershipOverride("swordKey")
		local afterClear = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(afterClear, 5)).toEqual(true)
		local _, ownsAfterClear = afterClear:Yield()
		expect(ownsAfterClear).toEqual(false)
		context.destroy()
	end)

	it("should treat SetOwnershipOverride(nil) as clearing the override", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		context.tracker:SetOwnershipOverride("swordKey", true)
		context.tracker:SetOwnershipOverride("swordKey", nil)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(false)
		context.destroy()
	end)

	it("should flip when the override is re-set", function()
		local context = setup()

		context.tracker:SetOwnershipOverride("swordKey", true)
		local first = context.tracker:PromiseOwnsAsset("swordKey")
		PromiseTestUtils.awaitSettled(first, 5)
		local _, firstOwns = first:Yield()
		expect(firstOwns).toEqual(true)

		context.tracker:SetOwnershipOverride("swordKey", false)
		local second = context.tracker:PromiseOwnsAsset("swordKey")
		PromiseTestUtils.awaitSettled(second, 5)
		local _, secondOwns = second:Yield()
		expect(secondOwns).toEqual(false)
		context.destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker:SetOwnershipOverride() combined keys", function()
	it("should honor an override set by key when queried by id", function()
		local context = setup()

		context.tracker:SetOwnershipOverride("swordKey", true)

		local promise = context.tracker:PromiseOwnsAsset(KEY_TO_ID.swordKey)
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(true)
		context.destroy()
	end)

	it("should honor an override set by id when queried by key", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(true)
		end)

		context.tracker:SetOwnershipOverride(KEY_TO_ID.swordKey, false)

		local promise = context.tracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(false)
		context.destroy()
	end)

	it("should not affect a different asset", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(false)
		end)

		context.tracker:SetOwnershipOverride("swordKey", true)

		local promise = context.tracker:PromiseOwnsAsset("shieldKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
		expect(owns).toEqual(false)
		context.destroy()
	end)

	it("should ignore an override for an unknown key without erroring", function()
		local context = setup()
		context.tracker:SetOwnershipOverride("doesNotExist", true)

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromiseOwnsAsset("doesNotExist"), 5)
		expect(outcome).toEqual("rejected")
		context.destroy()
	end)
end)

describe("PlayerAssetOwnershipTracker query failures", function()
	--[[
		Both seams the tracker handles a failure through, counted rather than watched: `warn` cannot be
		intercepted from here, and an unhandled rejection announces itself in the log rather than to the
		test. So the claim is pinned structurally -- the failure is reported once at the query, and every
		subscriber's continuation is consumed -- which is exactly what deleting either handler undoes.

		Spied on the class, so an instance built inside `func` is already covered. Restored in afterEach
		as well: a test killed mid-yield would otherwise leave the recorder installed for the whole run.
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
	end

	afterEach(function()
		trackerClass._warnQueryFailed = realWarn
		trackerClass._consumeObservedQueryFailure = realConsume
	end)

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

		local values = {}
		-- Typed `any`: the test place holds more than one copy of Subscription (a package graph
		-- duplicated per dependent), and a list inferred from one copy rejects another.
		local subs: { any } = {}
		for _ = 1, 3 do
			table.insert(
				subs,
				context.tracker:ObserveOwnsAsset(KEY_TO_ID.swordKey):Subscribe(function(value)
					table.insert(values, value)
				end)
			)
		end

		local asked = context.tracker:PromiseOwnsAsset("swordKey")
		pending:Reject("cloud refused")

		expect(PromiseTestUtils.awaitSettled(asked, 5)).toEqual(true)
		-- Yielded, not merely awaited: reading the outcome is this caller consuming its own copy, which is
		-- what a real caller does with the promise it asked for. Bound first, because Yield returns the
		-- rejection alongside the outcome and expect takes one argument.
		local askedOk = asked:Yield()
		expect(askedOk).toEqual(false)

		expect(PromiseTestUtils.awaitValue(function()
			return #consumed >= 3
		end, 5)).toEqual(true)

		-- One report for the query, one consumption per subscriber.
		expect(#reports).toEqual(1)
		expect(reports[1].assetId).toEqual(KEY_TO_ID.swordKey)
		expect(reports[1].err).toEqual("cloud refused")
		expect(#consumed).toEqual(3)

		-- An unresolvable asset emits nothing at all: silence reads as unresolved, where `false` would
		-- read as "does not own it" and turn a failed lookup into a refusal.
		expect(#values).toEqual(0)

		for _, sub in subs do
			sub:Destroy()
		end
		context.destroy()
	end)

	it("should not report an asset it was never given a callback to query", function()
		local context = setup()
		recordFailureHandling()

		-- No callback set: this realm cannot ask, rather than having asked and failed, so the rejection
		-- explains itself and nothing is reported.
		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromiseOwnsAsset("swordKey"), 5)
		expect(outcome).toEqual("rejected")

		expect(#reports).toEqual(0)
		context.destroy()
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
		context.destroy()
		expect(PromiseTestUtils.awaitSettled(asked, 5)).toEqual(true)
		local askedOk = asked:Yield()
		expect(askedOk).toEqual(false)

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

		local values = {}
		local sub = context.tracker:ObserveOwnsAsset(KEY_TO_ID.swordKey):Subscribe(function(value)
			table.insert(values, value)
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return values[#values] == false
		end, 5)).toEqual(true)

		context.tracker:SetOwnershipOverride(KEY_TO_ID.swordKey, true)
		expect(PromiseTestUtils.awaitValue(function()
			return values[#values] == true
		end, 5)).toEqual(true)

		context.tracker:ClearOwnershipOverride(KEY_TO_ID.swordKey)
		expect(PromiseTestUtils.awaitValue(function()
			return values[#values] == false
		end, 5)).toEqual(true)

		sub:Destroy()
		context.destroy()
	end)

	it("should emit false for a false override even when the cloud query reports ownership", function()
		local context = setup()
		context.tracker:SetQueryOwnershipCallback(function()
			return Promise.resolved(true)
		end)

		context.tracker:SetOwnershipOverride(KEY_TO_ID.swordKey, false)

		local values = {}
		local sub = context.tracker:ObserveOwnsAsset(KEY_TO_ID.swordKey):Subscribe(function(value)
			table.insert(values, value)
		end)

		expect(PromiseTestUtils.awaitValue(function()
			return values[#values] == false
		end, 5)).toEqual(true)

		sub:Destroy()
		context.destroy()
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
		local promise = clientTracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
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
		local promise = clientTracker:PromiseOwnsAsset("swordKey")
		expect(PromiseTestUtils.awaitSettled(promise, 5)).toEqual(true)
		local _, owns = promise:Yield()
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
