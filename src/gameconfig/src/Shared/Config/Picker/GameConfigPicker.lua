--[=[
	@class GameConfigPicker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local RxBinderUtils = require("RxBinderUtils")
local ObservableMapSet = require("ObservableMapSet")
local RxBrioUtils = require("RxBrioUtils")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")

local GameConfigPicker = setmetatable({}, BaseObject)
GameConfigPicker.ClassName = "GameConfigPicker"
GameConfigPicker.__index = GameConfigPicker

function GameConfigPicker.new(gameConfigBinder, gameConfigAssetBinder)
	local self = setmetatable(BaseObject.new(), GameConfigPicker)

	self._gameConfigBinder = assert(gameConfigBinder, "No gameConfigBinder")
	self._gameConfigAssetBinder = assert(gameConfigAssetBinder, "No gameConfigAssetBinder")

	self._gameIdToConfigSet = ObservableMapSet.new()
	self._maid:GiveTask(self._gameIdToConfigSet)

	self._maid:GiveTask(RxBinderUtils.observeAllBrio(self._gameConfigBinder)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local gameConfig = brio:GetValue()
			local maid = brio:ToMaid()

			maid:GiveTask(self._gameIdToConfigSet:Add(gameConfig, gameConfig:ObserveGameId()))
		end))

	return self
end

function GameConfigPicker:ObserveActiveAssetOfAssetIdBrio(assetId)
	assert(type(assetId) == "number", "Bad assetId")

	return self:ObserveActiveConfigsBrio(game.GameId)
		:Pipe({
			RxBrioUtils.flatMapBrio(function(gameConfig)
				return gameConfig:ObserveAssetByIdBrio(assetId)
			end);
		})
end

function GameConfigPicker:ObserveActiveAssetOfKeyBrio(assetKey)
	assert(type(assetKey) == "string", "Bad assetKey")

	return self:ObserveActiveConfigsBrio(game.GameId)
		:Pipe({
			RxBrioUtils.flatMapBrio(function(gameConfig)
				return gameConfig:ObserveAssetByKeyBrio(assetKey)
			end);
		})
end

function GameConfigPicker:ObserveActiveConfigsBrio()
	return self:_observeConfigsForGameIdBrio(game.GameId)
end

function GameConfigPicker:GetActiveConfigs()
	return self:_getConfigsForGameId(game.GameId)
end

function GameConfigPicker:FindFirstActiveAssetOfKey(assetType, assetKey)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetKey) == "string", "Bad assetKey")

	for _, gameConfig in pairs(self:GetActiveConfigs()) do
		for _, gameConfigAsset in pairs(gameConfig:GetAssetsOfTypeAndKey(assetType, assetKey)) do
			return gameConfigAsset
		end
	end

	return nil
end

function GameConfigPicker:GetAllActiveAssetsOfType(assetType)
	local assetList = {}
	for _, gameConfig in pairs(self:GetActiveConfigs()) do
		for _, gameConfigAsset in pairs(gameConfig:GetAssetsOfType(assetType)) do
			table.insert(assetList, gameConfigAsset)
		end
	end
	return assetList
end

function GameConfigPicker:_observeConfigsForGameIdBrio(gameId)
	assert(type(gameId) == "number", "Bad gameId")

	return self._gameIdToConfigSet:ObserveItemsForKeyBrio(gameId)
end

function GameConfigPicker:_getConfigsForGameId(gameId)
	assert(type(gameId) == "number", "Bad gameId")

	return self._gameIdToConfigSet:GetListForKey(gameId)
end

return GameConfigPicker