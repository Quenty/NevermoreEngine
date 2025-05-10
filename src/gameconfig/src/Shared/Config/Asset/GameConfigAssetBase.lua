--!strict
--[=[
	@class GameConfigAssetBase
]=]

local require = require(script.Parent.loader).load(script)

local AttributeValue = require("AttributeValue")
local BaseObject = require("BaseObject")
local CancelToken = require("CancelToken")
local GameConfigAssetConstants = require("GameConfigAssetConstants")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetUtils = require("GameConfigAssetUtils")
local GameConfigTranslator = require("GameConfigTranslator")
local JSONTranslator = require("JSONTranslator")
local Observable = require("Observable")
local Promise = require("Promise")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local ServiceBag = require("ServiceBag")

local GameConfigAssetBase = setmetatable({}, BaseObject)
GameConfigAssetBase.ClassName = "GameConfigAssetBase"
GameConfigAssetBase.__index = GameConfigAssetBase

export type GameConfigAssetBase = typeof(setmetatable(
	{} :: {
		_obj: Folder,
		_serviceBag: ServiceBag.ServiceBag,
		_nameTranslationKey: AttributeValue.AttributeValue<string>,
		_descriptionTranslationKey: AttributeValue.AttributeValue<string>,
		_configTranslator: JSONTranslator.JSONTranslator,
	},
	{} :: typeof({ __index = GameConfigAssetBase })
))

--[=[
	Constructs a new GameConfigAssetBase. Should be done via binder. This is a base class.
	@param obj Folder
	@param serviceBag ServiceBag
	@return GameConfigAssetBase
]=]
function GameConfigAssetBase.new(obj: Folder, serviceBag: ServiceBag.ServiceBag): GameConfigAssetBase
	local self: GameConfigAssetBase = setmetatable(BaseObject.new(obj) :: any, GameConfigAssetBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._nameTranslationKey = AttributeValue.new(self._obj, "NameTranslationKey", "assets.name.unknown")
	self._descriptionTranslationKey =
		AttributeValue.new(self._obj, "DescriptionTranslationKey", "assets.description.unknown")
	self._configTranslator = self._serviceBag:GetService(GameConfigTranslator)

	return self
end

--[=[
	Observes the translated name
	@return Observable<string>
]=]
function GameConfigAssetBase:ObserveTranslatedName(): Observable.Observable<string>
	return self:ObserveNameTranslationKey():Pipe({
		Rx.switchMap(function(key)
			return self._configTranslator:ObserveFormatByKey(key)
		end),
	})
end

--[=[
	Observes the translated description
	@return Observable<string>
]=]
function GameConfigAssetBase:ObserveTranslatedDescription(): Observable.Observable<string>
	return self:ObserveDescriptionTranslationKey():Pipe({
		Rx.switchMap(function(key)
			return self._configTranslator:ObserveFormatByKey(key)
		end),
	})
end

--[=[
	Sets the name translation key
	@param nameTranslationKey string?
]=]
function GameConfigAssetBase:SetNameTranslationKey(nameTranslationKey: string?)
	assert(type(nameTranslationKey) == "string" or nameTranslationKey == nil, "Bad nameTranslationKey")

	self._nameTranslationKey.Value = nameTranslationKey or "assets.name.unknown"
end

--[=[
	Sets the description translation key
	@param descriptionTranslationKey string?
]=]
function GameConfigAssetBase:SetDescriptionTranslationKey(descriptionTranslationKey: string?)
	assert(
		type(descriptionTranslationKey) == "string" or descriptionTranslationKey == nil,
		"Bad descriptionTranslationKey"
	)

	self._descriptionTranslationKey.Value = descriptionTranslationKey or "assets.description.unknown"
end

--[=[
	Gets the asset id
	@return number
]=]
function GameConfigAssetBase:GetAssetId(): number
	return self._obj:GetAttribute(GameConfigAssetConstants.ASSET_ID_ATTRIBUTE)
end

--[=[
	Observes the assetId
	@return Observable<number>
]=]
function GameConfigAssetBase:ObserveAssetId(): Observable.Observable<number>
	return RxAttributeUtils.observeAttribute(self._obj, GameConfigAssetConstants.ASSET_ID_ATTRIBUTE, nil)
end

--[=[
	Gets the asset type
	@return string?
]=]
function GameConfigAssetBase:GetAssetType(): string?
	return self._obj:GetAttribute(GameConfigAssetConstants.ASSET_TYPE_ATTRIBUTE)
end

--[=[
	Observes the asset type
	@return Observable<string?>
]=]
function GameConfigAssetBase:ObserveAssetType(): Observable.Observable<string?>
	return RxAttributeUtils.observeAttribute(self._obj, GameConfigAssetConstants.ASSET_TYPE_ATTRIBUTE, nil)
end

--[=[
	Observes the asset key
	@return Observable<string>
]=]
function GameConfigAssetBase:ObserveAssetKey(): Observable.Observable<string>
	return RxInstanceUtils.observeProperty(self._obj, "Name")
end

--[=[
	Gets the asset key
	@return string
]=]
function GameConfigAssetBase:GetAssetKey(): string
	return self._obj.Name
end

export type GameConfigAssetState = {
	assetId: number,
	assetKey: string,
	assetType: GameConfigAssetTypes.GameConfigAssetType,
}

--[=[
	Observes the asset state
	@return any
]=]
function GameConfigAssetBase:ObserveState(): Observable.Observable<GameConfigAssetState>
	return Rx.combineLatest({
		assetId = self:ObserveAssetId(),
		assetKey = self:ObserveAssetKey(),
		assetType = self:ObserveAssetType(),
	}) :: any
end

--[=[
	Promises the cloud price in Robux
	@param cancelToken CancelToken
	@return Promise<number?>
]=]
function GameConfigAssetBase:PromiseCloudPriceInRobux(cancelToken: CancelToken.CancelToken): Promise.Promise<number>
	return Rx.toPromise(self:ObserveCloudPriceInRobux(), cancelToken)
end

--[=[
	Promises the cloud price in Robux
	@param cancelToken CancelToken
	@return Promise<string?>
]=]
function GameConfigAssetBase:PromiseCloudName(cancelToken: CancelToken.CancelToken): Promise.Promise<string>
	return Rx.toPromise(self:ObserveCloudName(), cancelToken)
end
--[=[
	Promises the color of the game asset (for dialog and other systems)
	@param _cancelToken CancelToken
	@return Promise<Color3>
]=]
function GameConfigAssetBase:PromiseColor(_cancelToken: CancelToken.CancelToken): Promise.Promise<Color3>
	return Promise.resolved(Color3.fromRGB(66, 158, 166))
end

--[=[
	Promises the name translation key
	@param cancelToken CancelToken
	@return Promise<string?>
]=]
function GameConfigAssetBase:PromiseNameTranslationKey(cancelToken: CancelToken.CancelToken): Promise.Promise<string>
	return Rx.toPromise(self:ObserveNameTranslationKey(), cancelToken)
end

--[=[
	Observes the name translation key.
	@return Observable<string?>
]=]
function GameConfigAssetBase:ObserveNameTranslationKey(): Observable.Observable<string?>
	return self._nameTranslationKey:Observe()
end

--[=[
	Observes the description translation key.
	@return Observable<string?>
]=]
function GameConfigAssetBase:ObserveDescriptionTranslationKey(): Observable.Observable<string?>
	return self._descriptionTranslationKey:Observe()
end

--[=[
	Observes the cloud name. See [GameConfigAssetBase.ObserveNameTranslationKey] for
	translation keys.
	@return Observable<string?>
]=]
function GameConfigAssetBase:ObserveCloudName(): Observable.Observable<string?>
	return self:_observeCloudProperty({ "Name" }, "string")
end

--[=[
	Observes the cloud name. See [GameConfigAssetBase.ObserveDescriptionTranslationKey] for
	translation keys.
	@return Observable<string?>
]=]
function GameConfigAssetBase:ObserveCloudDescription(): Observable.Observable<string?>
	return self:_observeCloudProperty({ "Description" }, "string")
end

--[=[
	Observes the cost in Robux.
	@return Observable<number?>
]=]
function GameConfigAssetBase:ObserveCloudPriceInRobux(): Observable.Observable<number?>
	return self:_observeCloudProperty({ "PriceInRobux" }, "number")
end

--[=[
	@return Observable<number?>
]=]
function GameConfigAssetBase:ObserveCloudIconImageAssetId(): Observable.Observable<number?>
	return self:_observeCloudProperty({ "IconImageAssetId", "IconImageId" }, "number")
end

function GameConfigAssetBase:_observeCloudProperty(
	propertyNameList: { string },
	expectedType: string
): Observable.Observable<any?>
	assert(type(propertyNameList) == "table", "Bad propertyNameList")
	assert(type(expectedType) == "string", "Bad expectedType")

	return self:_observeCloudDataFromState():Pipe({
		Rx.map(function(data)
			if type(data) == "table" then
				for _, propertyName in propertyNameList do
					local result = data[propertyName]
					if type(result) == expectedType then
						return result
					end
				end

				return nil
			else
				return nil
			end
		end),
	})
end

function GameConfigAssetBase:_observeCloudDataFromState(): Observable.Observable<any?>
	if self._cloudDataObservable then
		return self._cloudDataObservable
	end

	self._cloudDataObservable = self:ObserveState():Pipe({
		Rx.switchMap(function(state): any
			if
				type(state.assetId) == "number"
				and type(state.assetType) == "string"
				and type(state.assetKey) == "string"
			then
				return Rx.fromPromise(self:_promiseCloudDataForState(state))
			else
				return Rx.of(nil)
			end
		end),
		Rx.distinct() :: any,
		Rx.shareReplay(1) :: any,
	})

	return self._cloudDataObservable
end

function GameConfigAssetBase:_promiseCloudDataForState(state: GameConfigAssetState): Promise.Promise<any?>
	return GameConfigAssetUtils.promiseCloudDataForAssetType(self._serviceBag, state.assetType, state.assetId)
end

return GameConfigAssetBase