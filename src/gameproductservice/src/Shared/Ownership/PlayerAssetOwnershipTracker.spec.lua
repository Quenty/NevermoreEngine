--!nonstrict
--[[
	Unit coverage for PlayerAssetOwnershipTracker. The tracker is constructed directly with a fake
	config picker (key -> id lookup) and a fake market tracker exposing only a Purchased signal, so
	no ServiceBag, GameConfig, or real MarketplaceService is involved. A plain Folder stands in for
	the player because the tracker only stores the player, never reads properties off it in the code
	paths under test. Each test destroys everything it creates so nothing leaks into the shared test
	place.

	@class PlayerAssetOwnershipTracker.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local Jest = require("Jest")
local Observable = require("Observable")
local PlayerAssetOwnershipTracker = require("PlayerAssetOwnershipTracker")
local Promise = require("Promise")
local PromiseTestUtils = require("PromiseTestUtils")
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

-- Minimal GameConfigPicker stand-in covering the two methods the tracker calls.
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
	local purchased = Signal.new()
	local marketTracker = { Purchased = purchased }
	local player = Instance.new("Folder")
	player.Name = "FakePlayer"

	local tracker =
		PlayerAssetOwnershipTracker.new(player, makeConfigPicker(), GameConfigAssetTypes.PASS, marketTracker)

	return {
		tracker = tracker,
		marketTracker = marketTracker,
		destroy = function()
			tracker:Destroy()
			purchased:Destroy()
			player:Destroy()
		end,
	}
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
		-- Should warn and no-op rather than throw.
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
