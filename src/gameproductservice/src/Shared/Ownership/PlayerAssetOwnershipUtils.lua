--[=[
	@class PlayerAssetOwnershipUtils
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local String = require("String")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")

local PlayerAssetOwnershipUtils = {}

function PlayerAssetOwnershipUtils.toKeyOwnedAttribute(assetType, assetKey)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetKey) == "string", "bad assetKey")

	return string.format("Owns_%s_%s", String.toCamelCase(assetType), assetKey)
end

function PlayerAssetOwnershipUtils.toIdOwnedAttribute(assetType, id)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	return string.format("Owns_%s_Id_%d", String.toCamelCase(assetType), id)
end

function PlayerAssetOwnershipUtils.getAttributeNames(configPicker, assetType, idOrKey)
	assert(configPicker, "Bad configPicker")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "idOrKey")

	local assetKeys = {}
	local assetIds = {}

	if type(idOrKey) == "number" then
		assetIds[idOrKey] = true

		for _, gameConfig in pairs(configPicker:GetActiveConfigs()) do
			for _, gameConfigAsset in pairs(gameConfig:GetAssetsOfTypeAndId(assetType, idOrKey)) do
				assetKeys[gameConfigAsset:GetAssetKey()] = true
			end
		end
	elseif type(idOrKey) == "string" then
		assetKeys[idOrKey] = true

		for _, gameConfig in pairs(configPicker:GetActiveConfigs()) do
			for _, gameConfigAsset in pairs(gameConfig:GetAssetsOfTypeAndKey(assetType, idOrKey)) do
				assetIds[gameConfigAsset:GetAssetId()] = true
			end
		end
	else
		error("Bad idOrKey")
	end

	local attributeNames = {}
	for assetId, _ in pairs(assetIds) do
		table.insert(attributeNames, PlayerAssetOwnershipUtils.toIdOwnedAttribute(assetType, assetId))
	end

	for assetKey, _ in pairs(assetKeys) do
		table.insert(attributeNames, PlayerAssetOwnershipUtils.toKeyOwnedAttribute(assetType, assetKey))
	end

	return attributeNames
end

function PlayerAssetOwnershipUtils.observeAttributeNamesBrio(configPicker, assetType, idOrKey)
	assert(configPicker, "Bad configPicker")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "idOrKey")

	return configPicker:ObserveActiveConfigsBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(activeConfig)
			if type(idOrKey) == "number" then
				return activeConfig:ObserveAssetByIdBrio(idOrKey)
			elseif type(idOrKey) == "string" then
				return activeConfig:ObserveAssetByKeyBrio(idOrKey)
			else
				return Rx.of(nil)
			end
		end);
		RxBrioUtils.flatMapBrio(function(gameConfigAsset)
			return PlayerAssetOwnershipUtils.observeAttributeNamesForGameConfigAssetBrio(assetType, gameConfigAsset)
		end);
	})
end

function PlayerAssetOwnershipUtils.observeAttributeNamesForGameConfigAssetBrio(assetType, gameConfigAsset)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(gameConfigAsset, "No gameConfigAsset")

	return Rx.merge({
		gameConfigAsset:ObserveAssetId():Pipe({
			Rx.map(function(assetId)
				return PlayerAssetOwnershipUtils.toIdOwnedAttribute(assetType, assetId)
			end);
			RxBrioUtils.switchToBrio();
		});
		gameConfigAsset:ObserveAssetKey():Pipe({
			Rx.map(function(assetKey)
				return PlayerAssetOwnershipUtils.toKeyOwnedAttribute(assetType, assetKey)
			end);
			RxBrioUtils.switchToBrio();
		});
	})
end

return PlayerAssetOwnershipUtils