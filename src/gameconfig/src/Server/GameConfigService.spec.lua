--!strict
--[[
	@class GameConfigService.spec.lua
]]
local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetUtils = require("GameConfigAssetUtils")
local GameConfigBindersServer = require("GameConfigBindersServer")
local GameConfigService = require("GameConfigService")
local GameConfigServiceConstants = require("GameConfigServiceConstants")
local Jest = require("Jest")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local describe = Jest.Globals.describe
local expect = Jest.Globals.expect
local it = Jest.Globals.it

local function setup()
	local maid = Maid.new()

	local serviceBag = maid:Add(ServiceBag.new())
	local gameConfigService: GameConfigService.GameConfigService = serviceBag:GetService(GameConfigService) :: any
	serviceBag:Init()
	serviceBag:Start()

	local binders: any = serviceBag:GetService(GameConfigBindersServer)

	return {
		maid = maid,
		serviceBag = serviceBag,
		gameConfigService = gameConfigService,
		binders = binders,
		Destroy = function(_self)
			maid:DoCleaning()
		end,
	}
end

local function getBoundDefaultConfigs(binders: any): { Instance }
	local found = {}
	for _, gameConfig in binders.GameConfig:GetAll() do
		local folder = gameConfig:GetFolder()
		if folder.Name == GameConfigServiceConstants.DEFAULT_CONFIG_NAME then
			table.insert(found, folder)
		end
	end
	return found
end

describe("GameConfigService:AddTypedAsset", function()
	it("reuses the default config and assets across ServiceBags", function()
		local first = setup()
		local firstAsset = first.gameConfigService:AddPlace("specCachedAcrossBags", 111)
		first:Destroy()

		local second = setup()
		local secondAsset = second.gameConfigService:AddPlace("specCachedAcrossBags", 111)

		expect(secondAsset).toBe(firstAsset)
		expect(#getBoundDefaultConfigs(second.binders)).toEqual(1)

		second:Destroy()
	end)

	it("adds a new asset when the id differs", function()
		local controller = setup()

		local first = controller.gameConfigService:AddPlace("specDifferentId", 111)
		local second = controller.gameConfigService:AddPlace("specDifferentId", 222)

		expect(second).never.toBe(first)
		expect(first.Parent).never.toBeNil()

		controller:Destroy()
	end)
end)

describe("GameConfigService:Destroy", function()
	it("does not destroy the default config", function()
		local controller = setup()

		local asset = controller.gameConfigService:AddPlace("specNotDestroyed", 111)
		local config = asset:FindFirstAncestor(GameConfigServiceConstants.DEFAULT_CONFIG_NAME)
		assert(config, "No default config")

		controller:Destroy()

		expect(config.Parent).never.toBeNil()
		expect(asset.Parent).never.toBeNil()
	end)

	it("keeps user-authored assets in the default config", function()
		local first = setup()
		local config = first.gameConfigService:AddPlace("specAuthoredSeed", 111).Parent
		assert(config, "No asset folder")

		local authored = GameConfigAssetUtils.create(
			first.binders.GameConfigAsset,
			GameConfigAssetTypes.PLACE,
			"specAuthoredAsset",
			333
		)
		authored.Parent = config
		first:Destroy()

		local second = setup()
		second.gameConfigService:AddPlace("specAuthoredAsset", 444)
		second:Destroy()

		expect(authored.Parent).toBe(config)
		expect(authored:GetAttribute("AssetId")).toEqual(333)
	end)
end)
