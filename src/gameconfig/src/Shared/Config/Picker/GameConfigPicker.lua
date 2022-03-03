--[=[
	Provides an interface to query game configurations from assets in the world.
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

--[=[
	Observes active assets of a given type. Great for badge views or other things.
	@param assetType
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker:ObserveActiveAssetOfTypeBrio(assetType: string)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	return self:ObserveActiveConfigsBrio(game.GameId)
		:Pipe({
			RxBrioUtils.flatMapBrio(function(gameConfig)
				return gameConfig:ObserveAssetByTypeBrio(assetType)
			end);
		})
end

--[=[
	Observes all active assets of a type and key.

	```lua
	maid:GiveTask(picker:ObserveActiveAssetOfAssetTypeAndKeyBrio(GameConfigAssetType.BADGE, "myBadge")
		:Pipe({
			RxStateStackUtils.topOfStack();
		}):Subscribe(function(activeBadge)
			print(activeBadge:GetId())
		end)
	```

	@param assetType
	@param assetKey
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker:ObserveActiveAssetOfAssetTypeAndKeyBrio(assetType: string, assetKey)
	assert(type(assetKey) == "string", "Bad assetKey")

	return self:ObserveActiveConfigsBrio(game.GameId)
		:Pipe({
			RxBrioUtils.flatMapBrio(function(gameConfig)
				return gameConfig:ObserveAssetByTypeAndKeyBrio(assetType, assetKey)
			end);
		})
end

--[=[
	Observes all active assets of a type and an id.

	@param assetType
	@param assetId
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker:ObserveActiveAssetOfAssetTypeAndIdBrio(assetType: string, assetId: number)
	assert(type(assetId) == "number", "Bad assetId")

	return self:ObserveActiveConfigsBrio(game.GameId)
		:Pipe({
			RxBrioUtils.flatMapBrio(function(gameConfig)
				return gameConfig:ObserveAssetByTypeAndIdBrio(assetType, assetId)
			end);
		})
end

--[=[
	Observes all active assets of an id

	@param assetId
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker:ObserveActiveAssetOfAssetIdBrio(assetId: number)
	assert(type(assetId) == "number", "Bad assetId")

	return self:ObserveActiveConfigsBrio(game.GameId)
		:Pipe({
			RxBrioUtils.flatMapBrio(function(gameConfig)
				return gameConfig:ObserveAssetByIdBrio(assetId)
			end);
		})
end

--[=[
	Observes all active assets of a key

	@param assetKey
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker:ObserveActiveAssetOfKeyBrio(assetKey: string)
	assert(type(assetKey) == "string", "Bad assetKey")

	return self:ObserveActiveConfigsBrio(game.GameId)
		:Pipe({
			RxBrioUtils.flatMapBrio(function(gameConfig)
				return gameConfig:ObserveAssetByKeyBrio(assetKey)
			end);
		})
end

--[=[
	Observes all active active assets

	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker:ObserveActiveConfigsBrio()
	return self:_observeConfigsForGameIdBrio(game.GameId)
end

--[=[
	Gets all active configs that exist

	@return { GameConfigAssetBase }
]=]
function GameConfigPicker:GetActiveConfigs()
	return self:_getConfigsForGameId(game.GameId)
end

--[=[
	Find the first asset of a given id

	@param assetType
	@param assetId
	@return GameConfigAssetBase
]=]
function GameConfigPicker:FindFirstActiveAssetOfId(assetType: string, assetId: number)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetId) == "number", "Bad assetId")

	for _, gameConfig in pairs(self:GetActiveConfigs()) do
		for _, gameConfigAsset in pairs(gameConfig:GetAssetsOfTypeAndId(assetType, assetId)) do
			return gameConfigAsset
		end
	end

	return nil
end

--[=[
	Find the first asset of a given key

	@param assetType
	@param assetKey
	@return GameConfigAssetBase
]=]
function GameConfigPicker:FindFirstActiveAssetOfKey(assetType: string, assetKey: string)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetKey) == "string", "Bad assetKey")

	for _, gameConfig in pairs(self:GetActiveConfigs()) do
		for _, gameConfigAsset in pairs(gameConfig:GetAssetsOfTypeAndKey(assetType, assetKey)) do
			return gameConfigAsset
		end
	end

	return nil
end

--[=[
	Gets all assets of a given type

	@param assetType
	@return { GameConfigAssetBase }
]=]
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