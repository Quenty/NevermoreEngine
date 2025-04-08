--[=[
	@class GameConfigBase
]=]

local require = require(script.Parent.loader).load(script)

local AttributeValue = require("AttributeValue")
local BaseObject = require("BaseObject")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local GameConfigConstants = require("GameConfigConstants")
local GameConfigUtils = require("GameConfigUtils")
local ObservableMapSet = require("ObservableMapSet")
local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local _GameConfigAssetBase = require("GameConfigAssetBase")
local _Observable = require("Observable")
local _Brio = require("Brio")

local GameConfigBase = setmetatable({}, BaseObject)
GameConfigBase.ClassName = "GameConfigBase"
GameConfigBase.__index = GameConfigBase

type GameConfigAssetType = GameConfigAssetTypes.GameConfigAssetType
type ObservableMapSet<K, V> = ObservableMapSet.ObservableMapSet<K, V>
type GameConfigAssetBase = _GameConfigAssetBase.GameConfigAssetBase

export type GameConfigBase = typeof(setmetatable(
	{} :: {
		_obj: Folder,
		_setupObservation: boolean,
		_gameConfigBindersServer: any,
		_gameId: AttributeValue.AttributeValue<number>,
		_assetTypeToAssetConfig: any,
		_assetTypeToAssetKeyMappings: {
			[GameConfigAssetType]: any,
		},
		_assetTypeToAssetIdMappings: {
			[GameConfigAssetType]: any,
		},
		_assetKeyToAssetConfig: any,
		_assetIdToAssetConfig: any,
	},
	{} :: typeof({ __index = GameConfigBase })
)) & BaseObject.BaseObject

--[=[
	Constructs a new game config.
	@param folder
	@return GameConfigBase
]=]
function GameConfigBase.new(folder: Folder): GameConfigBase
	local self = setmetatable(BaseObject.new(folder) :: any, GameConfigBase)

	self._gameId = AttributeValue.new(self._obj, GameConfigConstants.GAME_ID_ATTRIBUTE, game.GameId)

	-- Setup observable indexes
	self._assetTypeToAssetConfig = self._maid:Add(ObservableMapSet.new())
	self._assetKeyToAssetConfig = self._maid:Add(ObservableMapSet.new())
	self._assetIdToAssetConfig = self._maid:Add(ObservableMapSet.new())

	self._assetTypeToAssetKeyMappings = {}
	self._assetTypeToAssetIdMappings = {}

	-- Setup assetType mappings to key mapping observations
	for _, assetType in GameConfigAssetTypes do
		self._assetTypeToAssetKeyMappings[assetType] = ObservableMapSet.new()
		self._maid:GiveTask(self._assetTypeToAssetKeyMappings[assetType])

		self._assetTypeToAssetIdMappings[assetType] = ObservableMapSet.new()
		self._maid:GiveTask(self._assetTypeToAssetIdMappings[assetType])

		self._maid:GiveTask(self._assetTypeToAssetConfig:ObserveItemsForKeyBrio(assetType):Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local gameAssetConfig = brio:GetValue()
			local maid = brio:ToMaid()

			maid:GiveTask(
				self._assetTypeToAssetKeyMappings[assetType]:Push(gameAssetConfig:ObserveAssetKey(), gameAssetConfig)
			)
			maid:GiveTask(
				self._assetTypeToAssetIdMappings[assetType]:Push(gameAssetConfig:ObserveAssetId(), gameAssetConfig)
			)
		end))
	end

	return self
end

--[=[
	Gets the current folder
	@return Instance
]=]
function GameConfigBase.GetFolder(self: GameConfigBase): Folder
	return self._obj
end

--[=[
	Returns an array of all the assets of that type underneath this config
	@return { GameConfigAssetBase }
]=]
function GameConfigBase.GetAssetsOfType(self: GameConfigBase, assetType: GameConfigAssetType): { GameConfigAssetBase }
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	return self._assetTypeToAssetConfig:GetListForKey(assetType)
end

--[=[
	Returns an array of all the assets of that type underneath this config
	@param assetType
	@param assetKey
	@return { GameConfigAssetBase }
]=]
function GameConfigBase.GetAssetsOfTypeAndKey(self: GameConfigBase, assetType: GameConfigAssetType, assetKey: string)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetKey) == "string", "Bad assetKey")

	return self._assetTypeToAssetKeyMappings[assetType]:GetListForKey(assetKey)
end

--[=[
	Returns an array of all the assets of that type underneath this config
	@param assetType
	@param assetId
	@return { GameConfigAssetBase }
]=]
function GameConfigBase.GetAssetsOfTypeAndId(self: GameConfigBase, assetType: GameConfigAssetType, assetId: number)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetId) == "number", "Bad assetId")

	return self._assetTypeToAssetIdMappings[assetType]:GetListForKey(assetId)
end

--[=[
	Returns an observable matching these types and the key
	@param assetType
	@param assetKey
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigBase.ObserveAssetByTypeAndKeyBrio(
	self: GameConfigBase,
	assetType: GameConfigAssetType,
	assetKey: string
): _Observable.Observable<_Brio.Brio<GameConfigAssetBase>>
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetKey) == "string", "Bad assetKey")

	return self._assetTypeToAssetKeyMappings[assetType]:ObserveItemsForKeyBrio(assetKey)
end

--[=[
	Returns an observable matching these types and the id
	@param assetType
	@param assetId
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigBase.ObserveAssetByTypeAndIdBrio(
	self: GameConfigBase,
	assetType: GameConfigAssetType,
	assetId: number
): _Observable.Observable<_Brio.Brio<GameConfigAssetBase>>
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetId) == "number", "Bad assetId")

	return self._assetTypeToAssetIdMappings[assetType]:ObserveItemsForKeyBrio(assetId)
end

--[=[
	Observes all matching assets of this id
	@param assetId
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigBase.ObserveAssetByIdBrio(
	self: GameConfigBase,
	assetId: number
): _Observable.Observable<_Brio.Brio<GameConfigAssetBase>>
	assert(type(assetId) == "number", "Bad assetId")

	return self._assetIdToAssetConfig:ObserveItemsForKeyBrio(assetId)
end

--[=[
	Observes all matching assets of this key
	@param assetKey
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigBase.ObserveAssetByKeyBrio(
	self: GameConfigBase,
	assetKey: string
): _Observable.Observable<_Brio.Brio<GameConfigAssetBase>>
	assert(type(assetKey) == "string", "Bad assetKey")

	return self._assetKeyToAssetConfig:ObserveItemsForKeyBrio(assetKey)
end

--[=[
	Observes all matching assets of this type
	@param assetType
	@return Observable<Brio<GameConfigAssetBase>>
]=]
function GameConfigBase.ObserveAssetByTypeBrio(
	self: GameConfigBase,
	assetType: GameConfigAssetType
): _Observable.Observable<_Brio.Brio<GameConfigAssetBase>>
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	return self._assetTypeToAssetConfig:ObserveItemsForKeyBrio(assetType)
end

--[=[
	Initializes the observation. Should be called by the class inheriting this object.
]=]
function GameConfigBase.InitObservation(self: GameConfigBase)
	if self._setupObservation then
		return
	end

	self._setupObservation = true

	local observables = {}
	for _, assetType in GameConfigAssetTypes do
		table.insert(
			observables,
			self:_observeAssetFolderBrio(assetType):Pipe({
				RxBrioUtils.switchMapBrio(function(folder)
					return RxBinderUtils.observeBoundChildClassBrio(self:GetGameConfigAssetBinder(), folder)
				end),
			})
		)
	end

	-- hook up mapping
	self._maid:GiveTask(Rx.merge(observables):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local gameAssetConfig = brio:GetValue()
		local maid = brio:ToMaid()

		maid:GiveTask(self._assetTypeToAssetConfig:Push(gameAssetConfig:ObserveAssetType(), gameAssetConfig))
		maid:GiveTask(self._assetKeyToAssetConfig:Push(gameAssetConfig:ObserveAssetKey(), gameAssetConfig))
		maid:GiveTask(self._assetIdToAssetConfig:Push(gameAssetConfig:ObserveAssetId(), gameAssetConfig))
	end))
end

function GameConfigBase._observeAssetFolderBrio(self: GameConfigBase, assetType: GameConfigAssetType)
	return GameConfigUtils.observeAssetFolderBrio(self._obj, assetType)
end

--[=[
	Returns the game id for this profile.
	@return Observable<number>
]=]
function GameConfigBase.ObserveGameId(self: GameConfigBase): _Observable.Observable<number>
	return self._gameId:Observe()
end

--[=[
	Returns the game id
	@return number
]=]
function GameConfigBase.GetGameId(self: GameConfigBase): number?
	return self._gameId.Value
end

--[=[
	Returns this configuration's name
	@return string
]=]
function GameConfigBase.GetConfigName(self: GameConfigBase): string
	return self._obj.Name
end

--[=[
	Observes this configs name
	@return Observable<string>
]=]
function GameConfigBase.ObserveConfigName(self: GameConfigBase): _Observable.Observable<string>
	return RxInstanceUtils.observeProperty(self._obj, "Name")
end

function GameConfigBase.GetGameConfigAssetBinder(_self: GameConfigBase)
	error("Not implemented")
end

return GameConfigBase