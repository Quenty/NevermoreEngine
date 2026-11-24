--!strict
--[=[
	@class GameConfigUtils
]=]

local require = require(script.Parent.loader).load(script)

local AttributeUtils = require("AttributeUtils")
local Binder = require("Binder")
local Brio = require("Brio")
local GameConfigAssetConstants = require("GameConfigAssetConstants")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigConstants = require("GameConfigConstants")
local Observable = require("Observable")
local RxInstanceUtils = require("RxInstanceUtils")

local GameConfigUtils = {}

function GameConfigUtils.create(binder: Binder.Binder<any>, gameId: number): Folder
	assert(Binder.isBinder(binder), "Bad binder")
	assert(type(gameId) == "number", "Bad gameId")

	local config = Instance.new("Folder")
	config.Name = "GameConfig"

	AttributeUtils.initAttribute(config, GameConfigConstants.GAME_ID_ATTRIBUTE, gameId)

	for _, assetType in GameConfigAssetTypes :: any do
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
		local newFolder = Instance.new("Folder")
		newFolder.Name = folderName
		newFolder.Parent = config
		folder = newFolder
	end

	return folder :: Folder
end

--[=[
	Finds an asset in the config that matches the given type, key, id, and priority exactly

	@param config Folder
	@param assetType GameConfigAssetType
	@param assetKey string
	@param assetId number
	@param priority number?
	@return Instance?
]=]
function GameConfigUtils.findMatchingAsset(
	config: Folder,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
	assetKey: string,
	assetId: number,
	priority: number?
): Instance?
	assert(typeof(config) == "Instance", "Bad config")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetKey) == "string", "Bad assetKey")
	assert(type(assetId) == "number", "Bad assetId")

	local folder = config:FindFirstChild(GameConfigAssetTypeUtils.getPlural(assetType))
	if not folder then
		return nil
	end

	for _, child in folder:GetChildren() do
		if
			child.Name == assetKey
			and child:GetAttribute(GameConfigAssetConstants.ASSET_TYPE_ATTRIBUTE) == assetType
			and child:GetAttribute(GameConfigAssetConstants.ASSET_ID_ATTRIBUTE) == assetId
			and child:GetAttribute(GameConfigAssetConstants.PRIORITY_ATTRIBUTE) == priority
		then
			return child
		end
	end

	return nil
end

function GameConfigUtils.observeAssetFolderBrio(
	config: Folder,
	assetType: GameConfigAssetTypes.GameConfigAssetType
): Observable.Observable<Brio.Brio<Folder>>
	assert(typeof(config) == "Instance", "Bad config")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	local folderName = GameConfigAssetTypeUtils.getPlural(assetType)

	return (
		RxInstanceUtils.observeLastNamedChildBrio(config, "Folder", folderName) :: any
	) :: Observable.Observable<Brio.Brio<Folder>>
end

return GameConfigUtils
