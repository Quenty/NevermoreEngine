--[=[
	@class GameConfigUtils
]=]

local require = require(script.Parent.loader).load(script)

local AttributeUtils = require("AttributeUtils")
local GameConfigConstants = require("GameConfigConstants")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local Binder = require("Binder")
local RxInstanceUtils = require("RxInstanceUtils")
local _Observable = require("Observable")
local _Brio = require("Brio")

local GameConfigUtils = {}

function GameConfigUtils.create(binder, gameId: number): Folder
	assert(Binder.isBinder(binder), "Bad binder")
	assert(type(gameId) == "number", "Bad gameId")

	local config = Instance.new("Folder")
	config.Name = "GameConfig"

	AttributeUtils.initAttribute(config, GameConfigConstants.GAME_ID_ATTRIBUTE, gameId)

	for _, assetType in GameConfigAssetTypes do
		GameConfigUtils.getOrCreateAssetFolder(config, assetType)
	end

	binder:Bind(config)

	return config
end

function GameConfigUtils.getOrCreateAssetFolder(
	config: Folder,
	assetType: GameConfigAssetTypes.GameConfigAssetType
): Folder
	assert(typeof(config) == "Instance", "Bad config")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	local folderName = GameConfigAssetTypeUtils.getPlural(assetType)

	local folder = config:FindFirstChild(folderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = config
	end

	return folder
end

function GameConfigUtils.observeAssetFolderBrio(config: Folder, assetType: GameConfigAssetTypes.GameConfigAssetType): _Observable.Observable<_Brio.Brio<Folder>>
	assert(typeof(config) == "Instance", "Bad config")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	local folderName = GameConfigAssetTypeUtils.getPlural(assetType)

	return RxInstanceUtils.observeLastNamedChildBrio(config, "Folder", folderName)
end

return GameConfigUtils