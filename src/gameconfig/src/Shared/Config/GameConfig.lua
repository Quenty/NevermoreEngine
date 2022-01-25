--[=[
	@class GameConfig
]=]

local require = require(script.Parent.loader).load(script)

local HttpService = game:GetService("HttpService")

local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetGroup = require("GameConfigAssetGroup")

local GameConfig = {}
GameConfig.ClassName = "GameConfig"
GameConfig.__index = GameConfig

--[=[
	Constructs a new game config.
	@param experienceId number
	@return GameConfig
]=]
function GameConfig.new(experienceId)
	local self = setmetatable({}, GameConfig)

	self._assetGroupMap = {} -- [GameConfigAssetTypes] = GameConfigAssetGroup
	for _, assetType in pairs(GameConfigAssetTypes) do
		self._assetGroupMap[assetType] = GameConfigAssetGroup.new(assetType)
	end

	assert(type(experienceId) == "number", "Bad experienceId")
	self._experienceId = experienceId
	self._configId = HttpService:GenerateGUID(false)

	return self
end

function GameConfig:GetConfigId()
	return self._configId
end

--[=[
	Deserializes the game config
	@param gameConfigData any
	@return GameConfig
]=]
function GameConfig.deserialize(gameConfigData)
	assert(type(gameConfigData) == "table", "Bad gameConfigData")
	assert(type(gameConfigData.experienceId) == "number", "Bad gameConfigData.experienceId")
	assert(type(gameConfigData.assetGroupData) == "table", "Bad gameConfigData.assetGroupData")
	assert(type(gameConfigData.configId) == "string", "Bad gameConfigData.configId")

	local gameConfig = GameConfig.new(gameConfigData.experienceId)
	gameConfig._configId = gameConfigData.configId

	for assetType, assetGroupData in pairs(gameConfigData.assetGroupData) do
		-- overwrite the internal group data here
		gameConfig._assetGroupMap[assetType] = GameConfigAssetGroup.deserialize(assetGroupData)
	end

	return gameConfig
end

--[=[
	Serializes the game config
	@param gameConfig GameConfig
	@return any
]=]
function GameConfig.serialize(gameConfig)
	local gameConfigData = {}
	gameConfigData.experienceId = gameConfig:GetExperienceId()
	gameConfigData.assetGroupData = {}
	gameConfigData.configId = gameConfig:GetConfigId()


	for assetType, assetGroup in pairs(gameConfig:GetAssetGroupMap()) do
		gameConfigData.assetGroupData[assetType] = GameConfigAssetGroup.serialize(assetGroup)
	end

	return gameConfigData
end

--[=[
	Returns the experience id
	@return number
]=]
function GameConfig:GetExperienceId()
	return self._experienceId
end

--[=[
	Returns the asset group to a map
]=]
function GameConfig:GetAssetGroupMap()
	return self._assetGroupMap
end

--[=[
	@param assetType MantleAssetType
	@return GameConfigAssetGroup
]=]
function GameConfig:GetAssetGroup(assetType)
	assert(type(assetType) == "string", "Bad assetType")
	assert(self._assetGroupMap[assetType], "Bad assetType")

	return self._assetGroupMap[assetType]
end

--[=[
	@param assetType MantleAssetType
	@param assetId number
	@return MantleAssetData
]=]
function GameConfig:GetAssetDataById(assetType, assetId)
	assert(type(assetType) == "string", "Bad assetType")
	assert(type(assetId) == "number", "Bad assetId")

	return self._assetGroupMap[assetType]:GetDataById(assetId)
end

--[=[
	@param assetType MantleAssetType
	@param assetName string
	@return MantleAssetData
]=]
function GameConfig:GetAssetDataByName(assetType, assetName)
	assert(type(assetType) == "string", "Bad assetType")
	assert(type(assetName) == "number", "Bad assetName")

	return self._assetGroupMap[assetType]:GetDataByName(assetName)
end

return GameConfig