--!strict
--[[
	@class MarketplaceUtils.spec.lua
]]

local require = require(script.Parent.loader).load(script)

local Workspace = game:GetService("Workspace")

local Jest = require("Jest")
local MarketplaceServiceCache = require("MarketplaceServiceCache")
local MarketplaceUtils = require("MarketplaceUtils")
local PlayerMock = require("PlayerMock")
local PromiseTestUtils = require("PromiseTestUtils")

local afterEach = Jest.Globals.afterEach
local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local MOCK_USER_ID = 88771001
local GAME_PASS_ID = 111222333
local ASSET_ID = 444555666
local BUNDLE_ID = 777888999
local SUBSCRIPTION_ID = "EXP-88771001"

local createdMocks: { Player } = {}

local function makeMock(overrides: { [string]: any }?): Player
	local player = PlayerMock.new(overrides)
	player.Parent = Workspace
	table.insert(createdMocks, player)
	return player
end

local function awaitBool(promise: any): boolean
	expect(PromiseTestUtils.awaitSettled(promise, 5)).toBe(true)
	local ok, value = promise:Yield()
	expect(ok).toBe(true)
	return value
end

afterEach(function()
	for _, player in createdMocks do
		player:Destroy()
	end
	table.clear(createdMocks)
end)

describe("MarketplaceUtils.promiseUserOwnsGamePass", function()
	it("resolves false for a mock's userId with no injected ownership", function()
		makeMock({ UserId = MOCK_USER_ID })

		expect(awaitBool(MarketplaceUtils.promiseUserOwnsGamePass(MOCK_USER_ID, GAME_PASS_ID))).toBe(false)
	end)

	it("resolves the ownership injected on the mock", function()
		local player = makeMock({ UserId = MOCK_USER_ID })
		PlayerMock.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", GAME_PASS_ID, true)

		expect(awaitBool(MarketplaceUtils.promiseUserOwnsGamePass(MOCK_USER_ID, GAME_PASS_ID))).toBe(true)
	end)

	it("keys the injected ownership by gamePassId", function()
		local player = makeMock({ UserId = MOCK_USER_ID })
		PlayerMock.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", GAME_PASS_ID, true)

		expect(awaitBool(MarketplaceUtils.promiseUserOwnsGamePass(MOCK_USER_ID, GAME_PASS_ID + 1))).toBe(false)
	end)

	it("clears back to false when the injection is cleared", function()
		local player = makeMock({ UserId = MOCK_USER_ID })
		PlayerMock.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", GAME_PASS_ID, true)
		PlayerMock.writeLookup(player, "MarketplaceService.UserOwnsGamePassAsync", GAME_PASS_ID, nil)

		expect(awaitBool(MarketplaceUtils.promiseUserOwnsGamePass(MOCK_USER_ID, GAME_PASS_ID))).toBe(false)
	end)

	it("asserts on a non-number userId", function()
		expect(function()
			MarketplaceUtils.promiseUserOwnsGamePass("nope" :: any, GAME_PASS_ID)
		end).toThrow()
	end)
end)

describe("MarketplaceUtils.promisePlayerOwnsAsset", function()
	it("resolves false for a mock with no injected ownership", function()
		local player = makeMock({ UserId = MOCK_USER_ID })

		expect(awaitBool(MarketplaceUtils.promisePlayerOwnsAsset(player, ASSET_ID))).toBe(false)
	end)

	it("resolves the ownership injected on the mock", function()
		local player = makeMock({ UserId = MOCK_USER_ID })
		PlayerMock.writeLookup(player, "MarketplaceService.PlayerOwnsAsset", ASSET_ID, true)

		expect(awaitBool(MarketplaceUtils.promisePlayerOwnsAsset(player, ASSET_ID))).toBe(true)
	end)
end)

describe("MarketplaceUtils.promisePlayerOwnsAssetAsync", function()
	it("resolves false for a mock with no injected ownership", function()
		local player = makeMock({ UserId = MOCK_USER_ID })

		expect(awaitBool(MarketplaceUtils.promisePlayerOwnsAssetAsync(player, ASSET_ID))).toBe(false)
	end)

	it("resolves the ownership injected on the mock", function()
		local player = makeMock({ UserId = MOCK_USER_ID })
		PlayerMock.writeLookup(player, "MarketplaceService.PlayerOwnsAssetAsync", ASSET_ID, true)

		expect(awaitBool(MarketplaceUtils.promisePlayerOwnsAssetAsync(player, ASSET_ID))).toBe(true)
	end)

	it("reads a distinct domain from promisePlayerOwnsAsset", function()
		local player = makeMock({ UserId = MOCK_USER_ID })
		PlayerMock.writeLookup(player, "MarketplaceService.PlayerOwnsAsset", ASSET_ID, true)

		expect(awaitBool(MarketplaceUtils.promisePlayerOwnsAssetAsync(player, ASSET_ID))).toBe(false)
	end)
end)

describe("MarketplaceUtils.promisePlayerOwnsBundle", function()
	it("resolves false for a mock with no injected ownership", function()
		local player = makeMock({ UserId = MOCK_USER_ID })

		expect(awaitBool(MarketplaceUtils.promisePlayerOwnsBundle(player, BUNDLE_ID))).toBe(false)
	end)

	it("resolves the ownership injected on the mock", function()
		local player = makeMock({ UserId = MOCK_USER_ID })
		PlayerMock.writeLookup(player, "MarketplaceService.PlayerOwnsBundle", BUNDLE_ID, true)

		expect(awaitBool(MarketplaceUtils.promisePlayerOwnsBundle(player, BUNDLE_ID))).toBe(true)
	end)
end)

describe("MarketplaceUtils.promiseUserSubscriptionStatus", function()
	it("resolves an unsubscribed status for a mock with no injected status", function()
		local player = makeMock({ UserId = MOCK_USER_ID })

		local outcome, status =
			PromiseTestUtils.awaitOutcome(MarketplaceUtils.promiseUserSubscriptionStatus(player, SUBSCRIPTION_ID))
		expect(outcome).toBe("resolved")
		expect(status.IsSubscribed).toBe(false)
		expect(status.IsRenewing).toBe(false)
	end)

	it("resolves the status injected on the mock", function()
		local player = makeMock({ UserId = MOCK_USER_ID })
		PlayerMock.writeLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", SUBSCRIPTION_ID, {
			IsSubscribed = true,
			IsRenewing = true,
		})

		local outcome, status =
			PromiseTestUtils.awaitOutcome(MarketplaceUtils.promiseUserSubscriptionStatus(player, SUBSCRIPTION_ID))
		expect(outcome).toBe("resolved")
		expect(status.IsSubscribed).toBe(true)
		expect(status.IsRenewing).toBe(true)
	end)

	it("keys the injected status by subscriptionId", function()
		local player = makeMock({ UserId = MOCK_USER_ID })
		PlayerMock.writeLookup(player, "MarketplaceService.GetUserSubscriptionStatusAsync", SUBSCRIPTION_ID, {
			IsSubscribed = true,
			IsRenewing = false,
		})

		local outcome, status =
			PromiseTestUtils.awaitOutcome(MarketplaceUtils.promiseUserSubscriptionStatus(player, "EXP-other"))
		expect(outcome).toBe("resolved")
		expect(status.IsSubscribed).toBe(false)
	end)

	it("asserts on a non-player value", function()
		expect(function()
			MarketplaceUtils.promiseUserSubscriptionStatus(Instance.new("Folder") :: any, SUBSCRIPTION_ID)
		end).toThrow("Bad player")
	end)

	it("asserts on a non-string subscriptionId", function()
		local player = makeMock({ UserId = MOCK_USER_ID })

		expect(function()
			MarketplaceUtils.promiseUserSubscriptionStatus(player, 123 :: any)
		end).toThrow("Bad subscriptionId")
	end)
end)

describe("MarketplaceUtils.promiseProductInfo", function()
	it("asserts on a non-number assetId", function()
		expect(function()
			MarketplaceUtils.promiseProductInfo("nope" :: any, Enum.InfoType.GamePass)
		end).toThrow("Bad assetId")
	end)

	it("asserts on a non-EnumItem infoType", function()
		expect(function()
			MarketplaceUtils.promiseProductInfo(ASSET_ID, 5 :: any)
		end).toThrow("Bad infoType")
	end)
end)

describe("MarketplaceServiceCache.PromiseProductInfo", function()
	it("asserts on a non-number productId", function()
		expect(function()
			MarketplaceServiceCache.PromiseProductInfo(
				MarketplaceServiceCache :: any,
				"nope" :: any,
				Enum.InfoType.Asset
			)
		end).toThrow("Bad productId")
	end)
end)
