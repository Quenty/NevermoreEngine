--!strict
--[[
	Coverage for NevermoreManifestConfigProvider: it registers named manifest
	places as high-priority PLACE assets (so they win over a hand-authored place
	sharing the key) and skips nameless single-place-target entries.

	Registration is driven through the private _applyPlaces so the test controls
	the place table directly, rather than depending on a real deploy stamp on the
	manifest module. Each test uses distinct keys/ids; assets bind through global
	CollectionService tags under a shared parent, so they persist across tests in
	a run.

	@class NevermoreManifestConfigProvider.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigService = require("GameConfigService")
local Jest = require("Jest")
local NevermoreManifestConfigProvider = require("NevermoreManifestConfigProvider")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local PLACE: GameConfigAssetTypes.GameConfigAssetType = GameConfigAssetTypes.PLACE

local function newProvider()
	local serviceBag = ServiceBag.new()
	local gameConfigService = (serviceBag:GetService(GameConfigService) :: any) :: GameConfigService.GameConfigService
	local provider = (
		serviceBag:GetService(NevermoreManifestConfigProvider) :: any
	) :: NevermoreManifestConfigProvider.NevermoreManifestConfigProvider
	serviceBag:Init()
	serviceBag:Start()
	return serviceBag, gameConfigService, provider, gameConfigService:GetConfigPicker()
end

describe("NevermoreManifestConfigProvider", function()
	it("registers a named place as a resolvable PLACE asset", function()
		local serviceBag, _, provider, picker = newProvider()

		provider:_applyPlaces({
			{ name = "provChapterA", placeId = 555, universeId = 1 },
		})

		local asset = picker:FindFirstActiveAssetOfKey(PLACE, "provChapterA")
		expect(asset).never.toBeNil()
		assert(asset, "no asset")
		expect(asset:GetAssetId()).toEqual(555)

		serviceBag:Destroy()
	end)

	it("wins over a hand-authored place sharing the key", function()
		local serviceBag, gameConfigService, provider, picker = newProvider()

		gameConfigService:AddPlace("provChapterB", 111) -- hand-authored, priority 0
		provider:_applyPlaces({
			{ name = "provChapterB", placeId = 999, universeId = 1 },
		})

		local asset = picker:FindFirstActiveAssetOfKey(PLACE, "provChapterB")
		assert(asset, "no asset")
		expect(asset:GetAssetId()).toEqual(999)
		expect(asset:GetPriority() > 0).toEqual(true)

		serviceBag:Destroy()
	end)

	it("skips nameless (single-place-target) entries", function()
		local serviceBag, _, provider, picker = newProvider()

		expect(function()
			provider:_applyPlaces({
				{ placeId = 777, universeId = 1 },
			})
		end).never.toThrow()

		-- Nameless places have no config key to bind to, so nothing is registered.
		expect(picker:FindFirstActiveAssetOfId(PLACE, 777)).toBeNil()

		serviceBag:Destroy()
	end)

	it("registers nothing for an empty place table", function()
		local serviceBag, _, provider, picker = newProvider()

		provider:_applyPlaces({})
		expect(picker:FindFirstActiveAssetOfKey(PLACE, "provNeverAdded")).toBeNil()

		serviceBag:Destroy()
	end)
end)
