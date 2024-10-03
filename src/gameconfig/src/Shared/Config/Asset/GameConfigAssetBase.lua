--[=[
	@class GameConfigAssetBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local GameConfigAssetConstants = require("GameConfigAssetConstants")
local Promise = require("Promise")
local GameConfigAssetUtils = require("GameConfigAssetUtils")
local AttributeValue = require("AttributeValue")
local GameConfigTranslator = require("GameConfigTranslator")

local GameConfigAssetBase = setmetatable({}, BaseObject)
GameConfigAssetBase.ClassName = "GameConfigAssetBase"
GameConfigAssetBase.__index = GameConfigAssetBase

--[=[
	Constructs a new GameConfigAssetBase. Should be done via binder. This is a base class.
	@param obj Folder
	@param serviceBag ServiceBag
	@return GameConfigAssetBase
]=]
function GameConfigAssetBase.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), GameConfigAssetBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._nameTranslationKey = AttributeValue.new(self._obj, "NameTranslationKey", "assets.name.unknown")
	self._descriptionTranslationKey = AttributeValue.new(self._obj, "DescriptionTranslationKey", "assets.description.unknown")
	self._configTranslator = self._serviceBag:GetService(GameConfigTranslator)

	return self
end


--[=[
	Observes the translated name
	@return Observable<string>
]=]
function GameConfigAssetBase:ObserveTranslatedName()
	return self:ObserveNameTranslationKey():Pipe({
		Rx.switchMap(function(key)
			return self._configTranslator:ObserveFormatByKey(key)
		end)
	})
end

--[=[
	Observes the translated description
	@return Observable<string>
]=]
function GameConfigAssetBase:ObserveTranslatedDescription()
	return self:ObserveDescriptionTranslationKey():Pipe({
		Rx.switchMap(function(key)
			return self._configTranslator:ObserveFormatByKey(key)
		end)
	})
end

function GameConfigAssetBase:SetNameTranslationKey(nameTranslationKey)
	assert(type(nameTranslationKey) == "string" or nameTranslationKey == nil, "Bad nameTranslationKey")

	self._nameTranslationKey.Value = nameTranslationKey or "assets.name.unknown"
end

function GameConfigAssetBase:SetDescriptionTranslationKey(descriptionTranslationKey)
	assert(type(descriptionTranslationKey) == "string" or descriptionTranslationKey == nil, "Bad descriptionTranslationKey")

	self._descriptionTranslationKey.Value = descriptionTranslationKey or "assets.description.unknown"
end

--[=[
	Gets the asset id
	@return number
]=]
function GameConfigAssetBase:GetAssetId()
	return self._obj:GetAttribute(GameConfigAssetConstants.ASSET_ID_ATTRIBUTE)
end

--[=[
	Observes the assetId
	@return Observable<number>
]=]
function GameConfigAssetBase:ObserveAssetId()
	return RxAttributeUtils.observeAttribute(self._obj, GameConfigAssetConstants.ASSET_ID_ATTRIBUTE, nil)
end

--[=[
	Gets the asset type
	@return string?
]=]
function GameConfigAssetBase:GetAssetType()
	return self._obj:GetAttribute(GameConfigAssetConstants.ASSET_TYPE_ATTRIBUTE)
end

--[=[
	Observes the asset type
	@return Observable<string?>
]=]
function GameConfigAssetBase:ObserveAssetType()
	return RxAttributeUtils.observeAttribute(self._obj, GameConfigAssetConstants.ASSET_TYPE_ATTRIBUTE, nil)
end

--[=[
	Observes the asset key
	@return Observable<string>
]=]
function GameConfigAssetBase:ObserveAssetKey()
	return RxInstanceUtils.observeProperty(self._obj, "Name")
end

--[=[
	Gets the asset key
	@return string
]=]
function GameConfigAssetBase:GetAssetKey()
	return self._obj.Name
end

--[=[
	Observes the asset state
	@return any
]=]
function GameConfigAssetBase:ObserveState()
	return Rx.combineLatest({
		assetId = self:ObserveAssetId();
		assetKey = self:ObserveAssetKey();
		assetType = self:ObserveAssetType();
	})
end

--[=[
	Promises the cloud price in Robux
	@param cancelToken CancelToken
	@return Promise<string?>
]=]
function GameConfigAssetBase:PromiseCloudPriceInRobux(cancelToken)
	return Rx.toPromise(self:ObserveCloudPriceInRobux(), cancelToken)
end

--[=[
	Promises the cloud price in Robux
	@param cancelToken CancelToken
	@return Promise<string?>
]=]
function GameConfigAssetBase:PromiseCloudName(cancelToken)
	return Rx.toPromise(self:ObserveCloudName(), cancelToken)
end
--[=[
	Promises the color of the game asset (for dialog and other systems)
	@param _cancelToken CancelToken
	@return Promise<Color3>
]=]
function GameConfigAssetBase:PromiseColor(_cancelToken)
	return Promise.resolved(Color3.fromRGB(66, 158, 166))
end

--[=[
	Promises the name translation key
	@param cancelToken CancelToken
	@return Promise<string?>
]=]
function GameConfigAssetBase:PromiseNameTranslationKey(cancelToken)
	return Rx.toPromise(self:ObserveNameTranslationKey(), cancelToken)
end

--[=[
	Observes the name translation key.
	@return Observable<string?>
]=]
function GameConfigAssetBase:ObserveNameTranslationKey()
	return self._nameTranslationKey:Observe()
end

--[=[
	Observes the description translation key.
	@return Observable<string?>
]=]
function GameConfigAssetBase:ObserveDescriptionTranslationKey()
	return self._descriptionTranslationKey:Observe()
end

--[=[
	Observes the cloud name. See [GameConfigAssetBase.ObserveNameTranslationKey] for
	translation keys.
	@return Observable<string?>
]=]
function GameConfigAssetBase:ObserveCloudName()
	return self:_observeCloudProperty({ "Name" }, "string")
end

--[=[
	Observes the cloud name. See [GameConfigAssetBase.ObserveDescriptionTranslationKey] for
	translation keys.
	@return Observable<string?>
]=]
function GameConfigAssetBase:ObserveCloudDescription()
	return self:_observeCloudProperty({ "Description" }, "string")
end

--[=[
	Observes the cost in Robux.
	@return Observable<number?>
]=]
function GameConfigAssetBase:ObserveCloudPriceInRobux()
	return self:_observeCloudProperty({ "PriceInRobux" }, "number")
end

--[=[
	@return Observable<number?>
]=]
function GameConfigAssetBase:ObserveCloudIconImageAssetId()
	return self:_observeCloudProperty({ "IconImageAssetId", "IconImageId" }, "number")
end

function GameConfigAssetBase:_observeCloudProperty(propertyNameList, expectedType)
	assert(type(propertyNameList) == "table", "Bad propertyNameList")
	assert(type(expectedType) == "string", "Bad expectedType")

	return self:_observeCloudDataFromState():Pipe({
		Rx.map(function(data)
			if type(data) == "table" then
				for _, propertyName in pairs(propertyNameList) do
					local result = data[propertyName]
					if type(result) == expectedType then
						return result
					end
				end

				return nil
			else
				return nil
			end
		end)
	})
end

function GameConfigAssetBase:_observeCloudDataFromState()
	if self._cloudDataObservable then
		return self._cloudDataObservable
	end

	self._cloudDataObservable = self:ObserveState():Pipe({
		Rx.switchMap(function(state)
			if type(state.assetId) == "number" and type(state.assetType) == "string" and type(state.assetKey) == "string" then
				return Rx.fromPromise(self:_promiseCloudDataForState(state))
			else
				return Rx.of(nil)
			end
		end);
		Rx.distinct();
		Rx.shareReplay(1);
	})

	return self._cloudDataObservable
end

function GameConfigAssetBase:_promiseCloudDataForState(state)
	return GameConfigAssetUtils.promiseCloudDataForAssetType(self._serviceBag, state.assetType, state.assetId)
end

return GameConfigAssetBase