--[=[
	@class MantleConfigProvider
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetUtils = require("GameConfigAssetUtils")
local GameConfigBindersServer = require("GameConfigBindersServer")
local GameConfigService = require("GameConfigService")
local GameConfigUtils = require("GameConfigUtils")
local String = require("String")
local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local MantleConfigProvider = {}
MantleConfigProvider.ClassName = "MantleConfigProvider"
MantleConfigProvider.__index = MantleConfigProvider

function MantleConfigProvider.new(container)
	local self = setmetatable({}, MantleConfigProvider)

	self._container = assert(container, "No container")

	return self
end

function MantleConfigProvider:Init(serviceBag: _ServiceBag.ServiceBag)
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigService = self._serviceBag:GetService(GameConfigService)
	self._gameConfigBindersServer = self._serviceBag:GetService(GameConfigBindersServer)
	self._maid = Maid.new()

	for _, item in self._container:GetChildren() do
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
			self:_parseDataToConfig(data, item.Name)
		end
	end)

	assert(coroutine.status(current) == "dead", "Loading the mantle config yielded")
end


function MantleConfigProvider:_parseDataToConfig(mantleConfigData, name)
	assert(type(mantleConfigData) == "table", "Bad mantleConfigData")

	-- Just blind unpack these, we'll error if we can't find these.
	local gameId = mantleConfigData.experience_singleton.experience.assetId
	assert(type(gameId) == "number", "Failed to get gameId")

	local gameConfig = GameConfigUtils.create(self._gameConfigBindersServer.GameConfig, gameId)
	gameConfig.Name = name

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

		local asset = GameConfigAssetUtils.create(self._gameConfigBindersServer.GameConfigAsset, assetType, assetName, assetId)
		asset.Parent = GameConfigUtils.getOrCreateAssetFolder(gameConfig, assetType)
	end

	for key, value in mantleConfigData do
		if type(value) == "table" then
			addAsset("badge", GameConfigAssetTypes.BADGE, key, value)
			addAsset("pass", GameConfigAssetTypes.PASS, key, value)
			addAsset("product", GameConfigAssetTypes.PRODUCT, key, value)
			addAsset("place", GameConfigAssetTypes.PLACE, key, value)
		end
	end

	gameConfig.Parent = self._gameConfigService:GetPreferredParent()
	self._maid:GiveTask(gameConfig)

	return gameConfig
end

function MantleConfigProvider:Destroy()
	self._maid:DoCleaning()
end


return MantleConfigProvider