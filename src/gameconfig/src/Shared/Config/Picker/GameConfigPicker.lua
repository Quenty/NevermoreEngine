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
local Promise = require("Promise")
local GameConfigAssetUtils = require("GameConfigAssetUtils")
local _ServiceBag = require("ServiceBag")
local _GameConfigAssetTypes = require("GameConfigAssetTypes")
local _Observable = require("Observable")
local _Brio = require("Brio")
local _GameConfigAssetBase = require("GameConfigAssetBase")
local _Promise = require("Promise")
local _Binder = require("Binder")
local _Maid = require("Maid")

local GameConfigPicker = setmetatable({}, BaseObject)
GameConfigPicker.ClassName = "GameConfigPicker"
GameConfigPicker.__index = GameConfigPicker

export type GameConfigPicker = typeof(setmetatable(
	{} :: {
		_serviceBag: _ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = GameConfigPicker })
)) & BaseObject.BaseObject
type GameConfigAssetType = _GameConfigAssetTypes.GameConfigAssetType
type GameConfigAssetBase = _GameConfigAssetBase.GameConfigAssetBase

--[=[
	Constructs a new game config picker. Should be gotten by [GameConfigService].

	@param serviceBag ServiceBag
	@param gameConfigBinder Binder<GameConfig>
	@param gameConfigAssetBinder Binder<GameConfigAsset>
	@return GameConfigPicker
]=]
function GameConfigPicker.new(
	serviceBag: _ServiceBag.ServiceBag,
	gameConfigBinder,
	gameConfigAssetBinder
): GameConfigPicker
	local self = setmetatable(BaseObject.new(), GameConfigPicker)

	self._gameConfigBinder = assert(gameConfigBinder, "No gameConfigBinder")
	self._gameConfigAssetBinder = assert(gameConfigAssetBinder, "No gameConfigAssetBinder")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._gameIdToConfigSet = self._maid:Add(ObservableMapSet.new())

	self._maid:GiveTask(RxBinderUtils.observeAllBrio(self._gameConfigBinder):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local gameConfig = brio:GetValue()
		local maid = brio:ToMaid()

		maid:GiveTask(self._gameIdToConfigSet:Push(gameConfig:ObserveGameId(), gameConfig))
	end))

	return self
end

--[=[
	Observes active assets of a given type. Great for badge views or other things.
	@param assetType
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker.ObserveActiveAssetOfTypeBrio(
	self: GameConfigPicker,
	assetType: string
): _Observable.Observable<_Brio.Brio<GameConfigAssetBase>>
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	return self:ObserveActiveConfigsBrio(game.GameId):Pipe({
		RxBrioUtils.flatMapBrio(function(gameConfig)
			return gameConfig:ObserveAssetByTypeBrio(assetType)
		end),
	})
end

--[=[
	Observes all active assets of a type and key.

	```
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
function GameConfigPicker.ObserveActiveAssetOfAssetTypeAndKeyBrio(
	self: GameConfigPicker,
	assetType: string,
	assetKey: string
)
	assert(type(assetKey) == "string", "Bad assetKey")

	return self:ObserveActiveConfigsBrio(game.GameId):Pipe({
		RxBrioUtils.flatMapBrio(function(gameConfig)
			return gameConfig:ObserveAssetByTypeAndKeyBrio(assetType, assetKey)
		end),
	})
end

--[=[
	Observes all active assets of a type and an id.

	@param assetType
	@param assetId
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker.ObserveActiveAssetOfAssetTypeAndIdBrio(
	self: GameConfigPicker,
	assetType: string,
	assetId: number
)
	assert(type(assetId) == "number", "Bad assetId")

	return self:ObserveActiveConfigsBrio(game.GameId):Pipe({
		RxBrioUtils.flatMapBrio(function(gameConfig)
			return gameConfig:ObserveAssetByTypeAndIdBrio(assetType, assetId)
		end),
	})
end

--[=[
	Observes all active assets of an id

	@param assetId
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker.ObserveActiveAssetOfAssetIdBrio(
	self: GameConfigPicker,
	assetId: number
): _Observable.Observable<_Brio.Brio<GameConfigAssetBase>>
	assert(type(assetId) == "number", "Bad assetId")

	return self:ObserveActiveConfigsBrio(game.GameId):Pipe({
		RxBrioUtils.flatMapBrio(function(gameConfig)
			return gameConfig:ObserveAssetByIdBrio(assetId)
		end),
	})
end

--[=[
	Observes all active assets of a key

	@param assetKey
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker.ObserveActiveAssetOfKeyBrio(
	self: GameConfigPicker,
	assetKey: string
): _Observable.Observable<_Brio.Brio<GameConfigAssetBase>>
	assert(type(assetKey) == "string", "Bad assetKey")

	return self:ObserveActiveConfigsBrio(game.GameId):Pipe({
		RxBrioUtils.flatMapBrio(function(gameConfig)
			return gameConfig:ObserveAssetByKeyBrio(assetKey)
		end),
	})
end

--[=[
	Observes all active active assets

	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigPicker.ObserveActiveConfigsBrio(
	self: GameConfigPicker
): _Observable.Observable<_Brio.Brio<GameConfigAssetBase>>
	return self:_observeConfigsForGameIdBrio(game.GameId)
end

--[=[
	Gets all active configs that exist

	@return { GameConfigAssetBase }
]=]
function GameConfigPicker.GetActiveConfigs(self: GameConfigPicker): { GameConfigAssetBase }
	return self:_getConfigsForGameId(game.GameId)
end

--[=[
	Find the first asset of a given id

	@param assetType
	@param assetId
	@return GameConfigAssetBase?
]=]
function GameConfigPicker.FindFirstActiveAssetOfId(
	self: GameConfigPicker,
	assetType: string,
	assetId: number
): GameConfigAssetBase?
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetId) == "number", "Bad assetId")

	for _, gameConfig in self:GetActiveConfigs() do
		for _, gameConfigAsset in gameConfig:GetAssetsOfTypeAndId(assetType, assetId) do
			return gameConfigAsset
		end
	end

	return nil
end

--[=[
	Find the first asset of a given key

	@param assetType string
	@param assetIdOrKey string | number
	@return Promise<number>
]=]
function GameConfigPicker.PromisePriceInRobux(
	self: GameConfigPicker,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	assetIdOrKey
): _Promise.Promise<number>
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetIdOrKey) == "number" or type(assetIdOrKey) == "string", "Bad assetIdOrKey")

	if type(assetIdOrKey) == "string" then
		local asset = self:FindFirstActiveAssetOfKey(assetType, assetIdOrKey)
		if asset then
			return asset:PromiseCloudPriceInRobux()
		end

		return Promise.rejected(string.format("Could not turn %q into asset id", tostring(assetIdOrKey)))
	elseif type(assetIdOrKey) == "number" then
		local asset = self:FindFirstActiveAssetOfId(assetType, assetIdOrKey)
		if asset then
			-- TODO: Maybe cancel token
			return asset:PromiseCloudPriceInRobux()
		end

		return GameConfigAssetUtils.promiseCloudDataForAssetType(self._serviceBag, assetType, assetIdOrKey)
			:Then(function(cloudData)
				if type(cloudData.PriceInRobux) == "number" then
					return cloudData.PriceInRobux
				else
					return Promise.rejected()
				end
			end)
	else
		error("[GameConfigPicker.PromisePriceInRobux] - Bad assetIdOrKey")
	end
end

--[=[
	Find the first asset of a given key

	@param assetType
	@param assetKey
	@return GameConfigAssetBase?
]=]
function GameConfigPicker.FindFirstActiveAssetOfKey(
	self: GameConfigPicker,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	assetKey: string
): GameConfigAssetBase?
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetKey) == "string", "Bad assetKey")

	for _, gameConfig in self:GetActiveConfigs() do
		for _, gameConfigAsset in gameConfig:GetAssetsOfTypeAndKey(assetType, assetKey) do
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
function GameConfigPicker.GetAllActiveAssetsOfType(
	self: GameConfigPicker,
	assetType: _GameConfigAssetTypes.GameConfigAssetType
)
	local assetList = {}
	for _, gameConfig in self:GetActiveConfigs() do
		for _, gameConfigAsset in gameConfig:GetAssetsOfType(assetType) do
			table.insert(assetList, gameConfigAsset)
		end
	end
	return assetList
end

function GameConfigPicker._observeConfigsForGameIdBrio(
	self: GameConfigPicker,
	gameId: number
): _Observable.Observable<_Brio.Brio<GameConfigAssetBase>>
	assert(type(gameId) == "number", "Bad gameId")

	return self._gameIdToConfigSet:ObserveItemsForKeyBrio(gameId)
end

function GameConfigPicker._getConfigsForGameId(self: GameConfigPicker, gameId: number)
	assert(type(gameId) == "number", "Bad gameId")

	return self._gameIdToConfigSet:GetListForKey(gameId)
end

--[=[
	Converts an asset type and key to an id

	@param assetType GameConfigAssetType
	@param assetIdOrKey number | string
	@return number?
]=]
function GameConfigPicker.ToAssetId(
	self: GameConfigPicker,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	assetIdOrKey: string | number
): number?
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetIdOrKey) == "number" or type(assetIdOrKey) == "string", "Bad assetIdOrKey")

	if type(assetIdOrKey) == "string" then
		local asset = self:FindFirstActiveAssetOfKey(assetType, assetIdOrKey)
		if asset then
			return asset:GetAssetId()
		else
			return nil
		end
	end

	return assetIdOrKey
end

--[=[
	Observes a converted asset type and key to an id

	@param assetType GameConfigAssetType
	@param assetIdOrKey number | string
	@return Observable<Brio<number>>
]=]
function GameConfigPicker.ObserveToAssetIdBrio(
	self: GameConfigPicker,
	assetType: _GameConfigAssetTypes.GameConfigAssetType,
	assetIdOrKey: string | number
): _Observable.Observable<_Brio.Brio<number>>
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetIdOrKey) == "number" or type(assetIdOrKey) == "string", "Bad assetIdOrKey")

	if type(assetIdOrKey) == "string" then
		return self:ObserveActiveAssetOfAssetTypeAndKeyBrio(assetType, assetIdOrKey):Pipe({
			RxBrioUtils.switchMapBrio(function(asset)
				return asset:ObserveAssetId()
			end),
		})
	elseif type(assetIdOrKey) == "number" then
		return RxBrioUtils.of(assetIdOrKey)
	else
		error("Bad idOrKey")
	end
end

return GameConfigPicker
