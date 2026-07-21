--!strict
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
local GameConfigPicker = require("GameConfigPicker")
local Jest = require("Jest")
local Observable = require("Observable")
local PlayerAssetOwnershipTracker = require("PlayerAssetOwnershipTracker")
local PlayerProductOwnershipOverrideUtils = require("PlayerProductOwnershipOverrideUtils")
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

	local tracker = PlayerAssetOwnershipTracker.new(
		(player :: any) :: Player,
		(makeConfigPicker() :: any) :: GameConfigPicker.GameConfigPicker,
		GameConfigAssetTypes.PASS,
		marketTracker
	)

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
		-- Should warn and no-op rather than throw.
		context.tracker:SetOwnershipOverride("doesNotExist", true)

		local outcome = PromiseTestUtils.awaitOutcome(context.tracker:PromiseOwnsAsset("doesNotExist"), 5)
		expect(outcome).toEqual("rejected")
		context.destroy()
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
		local player = Instance.new("Folder")

		-- The "server" tracker authors the override, writing the replicated attribute.
		local serverTracker, destroyServer = makeTracker(player)
		serverTracker:SetOwnershipOverride("swordKey", true)

		-- The "client" tracker binds later over the same (replicated) player attribute.
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
		local player = Instance.new("Folder")

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
		local player = Instance.new("Folder")
		local tracker, destroy = makeTracker(player)

		tracker:SetOwnershipOverride("doesNotExist", true)
		expect(player:GetAttribute(ATTRIBUTE_NAME)).toEqual(nil)

		destroy()
		player:Destroy()
	end)

	it("should remove the attribute once the only override is cleared", function()
		local player = Instance.new("Folder")
		local tracker, destroy = makeTracker(player)

		tracker:SetOwnershipOverride("swordKey", true)
		expect(player:GetAttribute(ATTRIBUTE_NAME) == nil).toEqual(false)

		tracker:ClearOwnershipOverride("swordKey")
		expect(player:GetAttribute(ATTRIBUTE_NAME)).toEqual(nil)

		destroy()
		player:Destroy()
	end)
end)
