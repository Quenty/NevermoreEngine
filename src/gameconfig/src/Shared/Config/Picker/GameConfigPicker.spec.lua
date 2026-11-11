--!strict
--[[
	@class GameConfigPicker.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetUtils = require("GameConfigAssetUtils")
local GameConfigBindersServer = require("GameConfigBindersServer")
local GameConfigService = require("GameConfigService")
local GameConfigUtils = require("GameConfigUtils")
local Jest = require("Jest")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local PLACE: GameConfigAssetTypes.GameConfigAssetType = GameConfigAssetTypes.PLACE

local function newPicker()
	local serviceBag = ServiceBag.new()
	local gameConfigService: GameConfigService.GameConfigService = serviceBag:GetService(GameConfigService) :: any
	serviceBag:Init()
	serviceBag:Start()
	return serviceBag, gameConfigService, gameConfigService:GetConfigPicker()
end

describe("GameConfigPicker.FindFirstActiveAssetOfKey priority", function()
	it("resolves a single added place", function()
		local serviceBag, gameConfigService, picker = newPicker()

		gameConfigService:AddPlace("specResolve", 111)
		local asset = picker:FindFirstActiveAssetOfKey(PLACE, "specResolve")
		expect(asset).never.toBeNil()
		assert(asset, "No asset")
		expect(asset:GetAssetId()).toEqual(111)

		serviceBag:Destroy()
	end)

	it("defaults an asset without a priority to DEFAULT_PRIORITY", function()
		local serviceBag, gameConfigService, picker = newPicker()

		gameConfigService:AddPlace("specDefaultPriority", 111)
		local asset = picker:FindFirstActiveAssetOfKey(PLACE, "specDefaultPriority")
		assert(asset, "No asset")
		expect(asset:GetPriority()).toEqual(0)

		serviceBag:Destroy()
	end)

	it("prefers the higher-priority asset added after a default one", function()
		local serviceBag, gameConfigService, picker = newPicker()

		gameConfigService:AddPlace("specClashAfter", 111)
		gameConfigService:AddPlace("specClashAfter", 222, 100)

		local asset = picker:FindFirstActiveAssetOfKey(PLACE, "specClashAfter")
		assert(asset, "No asset")
		expect(asset:GetAssetId()).toEqual(222)

		serviceBag:Destroy()
	end)

	it("prefers the higher-priority asset even when added first", function()
		local serviceBag, gameConfigService, picker = newPicker()

		gameConfigService:AddPlace("specClashFirst", 222, 100)
		gameConfigService:AddPlace("specClashFirst", 111)

		local asset = picker:FindFirstActiveAssetOfKey(PLACE, "specClashFirst")
		assert(asset, "No asset")
		expect(asset:GetAssetId()).toEqual(222)

		serviceBag:Destroy()
	end)

	it("resolves deterministically to a matching asset when priorities tie", function()
		local serviceBag, gameConfigService, picker = newPicker()

		gameConfigService:AddPlace("specTie", 111)
		gameConfigService:AddPlace("specTie", 222)

		local firstAsset = picker:FindFirstActiveAssetOfKey(PLACE, "specTie")
		local secondAsset = picker:FindFirstActiveAssetOfKey(PLACE, "specTie")
		assert(firstAsset, "No firstAsset")
		assert(secondAsset, "No secondAsset")
		local first = firstAsset:GetAssetId()
		local second = secondAsset:GetAssetId()
		expect(first).toEqual(second)
		expect(first == 111 or first == 222).toEqual(true)

		serviceBag:Destroy()
	end)

	it("returns nil for a key with no active asset", function()
		local serviceBag, _, picker = newPicker()

		expect(picker:FindFirstActiveAssetOfKey(PLACE, "specDefinitelyMissing")).toBeNil()

		serviceBag:Destroy()
	end)
end)

describe("GameConfigPicker gameId gate dominates priority", function()
	local function addInactiveConfigPlace(
		serviceBag: any,
		gameConfigService: any,
		assetKey: string,
		placeId: number,
		priority: number
	): Instance
		local binders = serviceBag:GetService(GameConfigBindersServer)
		local config = GameConfigUtils.create(binders.GameConfig, game.GameId + 1)
		config.Parent = gameConfigService:GetPreferredParent()

		local asset = GameConfigAssetUtils.create(binders.GameConfigAsset, PLACE, assetKey, placeId, priority)
		asset.Parent = GameConfigUtils.getOrCreateAssetFolder(config, PLACE)

		return config
	end

	it("excludes a high-priority asset whose config gameId does not match", function()
		local serviceBag, gameConfigService, picker = newPicker()

		local inactive = addInactiveConfigPlace(serviceBag, gameConfigService, "specGateOnly", 888, 5000)

		expect(picker:FindFirstActiveAssetOfKey(PLACE, "specGateOnly")).toBeNil()

		inactive:Destroy()
		serviceBag:Destroy()
	end)

	it("keeps a lower-priority active asset over a higher-priority wrong-gameId one", function()
		local serviceBag, gameConfigService, picker = newPicker()

		local inactive = addInactiveConfigPlace(serviceBag, gameConfigService, "specGateBeatsPriority", 888, 5000)
		gameConfigService:AddPlace("specGateBeatsPriority", 111)

		local resolved = picker:FindFirstActiveAssetOfKey(PLACE, "specGateBeatsPriority")
		expect(resolved).never.toBeNil()
		assert(resolved, "No resolved asset")
		expect(resolved:GetAssetId()).toEqual(111)

		inactive:Destroy()
		serviceBag:Destroy()
	end)
end)
