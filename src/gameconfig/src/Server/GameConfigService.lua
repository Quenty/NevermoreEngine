--[=[
	@class GameConfigService
]=]

local require = require(script.Parent.loader).load(script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfigUtils = require("GameConfigUtils")
local GameConfigPicker = require("GameConfigPicker")
local Maid = require("Maid")
local PreferredParentUtils = require("PreferredParentUtils")
local GameConfigAssetUtils = require("GameConfigAssetUtils")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigServiceConstants = require("GameConfigServiceConstants")

local GameConfigService = {}
GameConfigService.ServiceName = "GameConfigService"

function GameConfigService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("CmdrService"))

	-- Internal
	self._serviceBag:GetService(require("GameConfigCommandService"))
	self._binders = self._serviceBag:GetService(require("GameConfigBindersServer"))

	-- Setup picker
	self._configPicker = GameConfigPicker.new(self._binders.GameConfig, self._binders.GameConfigAsset)
	self._maid:GiveTask(self._configPicker)

	self._getPreferredParent = PreferredParentUtils.createPreferredParentRetriever(ReplicatedStorage, "GameConfigs")
end

function GameConfigService:AddBadge(assetKey, badgeId)
	self:AddAsset(GameConfigAssetTypes.BADGE, assetKey, badgeId)
end

function GameConfigService:AddProduct(assetKey, productId)
	self:AddAsset(GameConfigAssetTypes.PRODUCT, assetKey, productId)
end

function GameConfigService:AddPass(assetKey, passId)
	self:AddAsset(GameConfigAssetTypes.PASS, assetKey, passId)
end

function GameConfigService:AddPlace(assetKey, placeId)
	self:AddAsset(GameConfigAssetTypes.PLACE, assetKey, placeId)
end

function GameConfigService:AddAsset(assetType, assetKey, assetId)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetKey) == "string", "Bad assetKey")
	assert(type(assetId) == "number", "Bad assetId")

	local gameConfig = self:_getOrCreateDefaultGameConfig()

	local asset = GameConfigAssetUtils.create(self._binders.GameConfigAsset, assetType, assetKey, assetId)
	asset.Parent = GameConfigUtils.getOrCreateAssetFolder(gameConfig, assetType)

	return asset
end

function GameConfigService:Start()
	assert(self._serviceBag, "Not initialized")
	self._started = true
end

function GameConfigService:GetConfigPicker()
	return self._configPicker
end

function GameConfigService:GetPreferredParent()
	return self._getPreferredParent()
end

function GameConfigService:_getOrCreateDefaultGameConfig()
	for _, item in pairs(self._binders.GameConfig:GetAll()) do
		if item:GetGameId() == game.GameId and item:GetConfigName() == GameConfigServiceConstants.DEFAULT_CONFIG_NAME then
			return item:GetFolder()
		end
	end

	local config = GameConfigUtils.create(self._binders.GameConfig, game.GameId)
	config.Name = GameConfigServiceConstants.DEFAULT_CONFIG_NAME
	config.Parent = self:GetPreferredParent()

	return config
end

function GameConfigService:Destroy()
	self._maid:DoCleaning()
end

return GameConfigService