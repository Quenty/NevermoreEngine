--[=[
	@class MantleConfigProvider
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local GameConfigService = require("GameConfigService")
local GameConfig = require("GameConfig")
local String = require("String")
local GameConfigAssetDataUtils = require("GameConfigAssetDataUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")

local MantleConfigProvider = setmetatable({}, BaseObject)
MantleConfigProvider.ClassName = "MantleConfigProvider"
MantleConfigProvider.__index = MantleConfigProvider

function MantleConfigProvider.new(container)
	local self = setmetatable(BaseObject.new(), MantleConfigProvider)

	self._container = assert(container, "No container")

	return self
end

function MantleConfigProvider:Init(serviceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigService = self._serviceBag:GetService(GameConfigService)

	for _, item in pairs(self._container:GetChildren()) do
		if item:IsA("ModuleScript") then
			self:_loadConfig(item)
		end
	end
end

function MantleConfigProvider:_loadConfig(item)
	local current

	task.spawn(function()
		current = coroutine.running()
		local data = require(item)
		if type(data) == "table" then
			local config = self:_parseDataToConfig(data)
			self._gameConfigService:AddConfig(config)
		end
	end)

	assert(coroutine.status(current) == "dead", "Loading the mantle config yielded")
end


function MantleConfigProvider:_parseDataToConfig(mantleConfigData)
	assert(type(mantleConfigData) == "table", "Bad mantleConfigData")

	-- Just blind unpack these, we'll error if we can't find these.
	local experienceId = mantleConfigData.experience_singleton.experience.assetId
	assert(type(experienceId) == "number", "Failed to get experienceId")

	local gameConfig = GameConfig.new(experienceId)

	local function getIcon(mantleType, assetName)
		local entryName = mantleType .. "Icon"
		local entryKey = entryName .. "_" .. assetName

		local iconEntry = mantleConfigData[entryKey]
		local iconData = iconEntry and iconEntry[entryName]
		local assetId = iconData and iconData.assetId

		return assetId
	end

	local function addAsset(mantleType, assetType, key, value)
		local data = value[mantleType]

		if not data then
			return
		end

		local prefix = mantleType .. "_"
		local assetName = String.removePrefix(key, prefix)

		local iconId = getIcon(mantleType, assetName)
		if type(iconId) ~= "number" then
			iconId = tonumber(data.initialIconAssetId)
		end

		local assetId = data.assetId
		if type(assetId) ~= "number" then
			return
		end

		local assetData = GameConfigAssetDataUtils.createAssetData(assetType, assetName, assetId, iconId)
		local assetGroup = gameConfig:GetAssetGroup(assetType)
		assetGroup:AddAssetData(assetData)
	end

	for key, value in pairs(mantleConfigData) do
		if type(value) == "table" then
			addAsset("badge", GameConfigAssetTypes.BADGE, key, value)
			addAsset("pass", GameConfigAssetTypes.PASS, key, value)
			addAsset("product", GameConfigAssetTypes.PRODUCT, key, value)
			addAsset("place", GameConfigAssetTypes.PLACE, key, value)
		end
	end

	return gameConfig
end


return MantleConfigProvider