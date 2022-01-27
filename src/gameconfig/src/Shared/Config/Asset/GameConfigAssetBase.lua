--[=[
	@class GameConfigAssetBase
]=]

local require = require(script.Parent.loader).load(script)

local BadgeUtils = require("BadgeUtils")
local BaseObject = require("BaseObject")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local MarketplaceUtils = require("MarketplaceUtils")
local GameConfigAssetConstants = require("GameConfigAssetConstants")

local GameConfigAssetBase = setmetatable({}, BaseObject)
GameConfigAssetBase.ClassName = "GameConfigAssetBase"
GameConfigAssetBase.__index = GameConfigAssetBase

function GameConfigAssetBase.new(obj)
	local self = setmetatable(BaseObject.new(obj), GameConfigAssetBase)

	return self
end

function GameConfigAssetBase:GetAssetId()
	return self._obj:GetAttribute(GameConfigAssetConstants.ASSET_ID_ATTRIBUTE)
end

function GameConfigAssetBase:ObserveAssetId()
	return RxAttributeUtils.observeAttribute(self._obj, GameConfigAssetConstants.ASSET_ID_ATTRIBUTE, nil)
end

function GameConfigAssetBase:GetAssetType()
	return self._obj:GetAttribute(GameConfigAssetConstants.ASSET_TYPE_ATTRIBUTE)
end

function GameConfigAssetBase:ObserveAssetType()
	return RxAttributeUtils.observeAttribute(self._obj, GameConfigAssetConstants.ASSET_TYPE_ATTRIBUTE, nil)
end

function GameConfigAssetBase:ObserveAssetKey()
	return RxInstanceUtils.observeProperty(self._obj, "Name")
end

function GameConfigAssetBase:GetAssetKey()
	return self._obj.Name
end

function GameConfigAssetBase:ObserveState()
	-- TODO: Multicast

	return Rx.combineLatest({
		assetId = self:ObserveAssetId();
		assetKey = self:ObserveAssetKey();
		assetType = self:ObserveAssetType();
	})
end

function GameConfigAssetBase:ObserveNameTranslationKey()
	return self:_observeTranslationKey("name")
end

function GameConfigAssetBase:ObserveDescriptionTranslationKey()
	return self:_observeTranslationKey("description")
end

function GameConfigAssetBase:_observeTranslationKey(postfix)
	-- TODO: Multicast

	return self:ObserveState():Pipe({
		Rx.map(function(state)
			if type(state) == "table" and type(state.assetType) == "string" and type(state.assetKey) == "string" then
				return ("cloud.%s.%s.%s"):format(state.assetType, state.assetKey, postfix)
			else
				return nil
			end
		end)
	})
end

function GameConfigAssetBase:ObserveCloudName()
	return self:_observeCloudProperty("Name", "string")
end

function GameConfigAssetBase:ObserveCloudDescription()
	return self:_observeCloudProperty("Description", "string")
end

function GameConfigAssetBase:ObserveCloudPriceInRobux()
	return self:_observeCloudProperty("PriceInRobux", "number")
end

function GameConfigAssetBase:_observeCloudProperty(propertyName, expectedType)
	assert(type(propertyName) == "string", "Bad propertyName")
	assert(type(expectedType) == "string", "Bad expectedType")

	return self:ObserveDataFromState():Pipe({
		Rx.map(function(data)
			if type(data) == "table" then
				local result = data[propertyName]
				if type(result) == expectedType then
					return result
				end
			else
				return nil
			end
		end)
	})
end

function GameConfigAssetBase:ObserveDataFromState()
	-- TODO: Multicast

	return self:ObserveState():Pipe({
		Rx.switchMap(function(state)
			if type(state.assetId) == "number" and type(state.assetType) == "string" and type(state.assetKey) == "string" then
				return Rx.fromPromise(self:_promiseDataForState(state))
			else
				return Rx.of(nil)
			end
		end);
	})
end

function GameConfigAssetBase:_promiseDataForState(state)
	-- We really hope this stuff is cached
	if state.assetType == GameConfigAssetTypes.BADGE then
		return BadgeUtils.promiseBadgeInfo(state.assetId)
	elseif state.assetType == GameConfigAssetTypes.PRODUCT then
		return MarketplaceUtils.promiseProductInfo(state.assetId, Enum.InfoType.Product)
	elseif state.assetType == GameConfigAssetTypes.PASS then
		return MarketplaceUtils.promiseProductInfo(state.assetId, Enum.InfoType.GamePass)
	elseif state.assetType == GameConfigAssetTypes.PLACE then
		return MarketplaceUtils.promiseProductInfo(state.assetId, Enum.InfoType.Asset)
	else
		warn(("Unknown GameConfigAssetType %q. Ignoring asset."):format(tostring(state.assetType)))
		return Rx.of(nil)
	end
end

return GameConfigAssetBase