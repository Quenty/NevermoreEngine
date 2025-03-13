--[=[
	@class CatalogSearchServiceCache
]=]

local require = require(script.Parent.loader).load(script)

local MemorizeUtils = require("MemorizeUtils")
local AvatarEditorUtils = require("AvatarEditorUtils")
local Aggregator = require("Aggregator")
local Maid = require("Maid")
local PagesProxy = require("PagesProxy")
local _ServiceBag = require("ServiceBag")

local CatalogSearchServiceCache = {}
CatalogSearchServiceCache.ServiceName = "CatalogSearchServiceCache"

function CatalogSearchServiceCache:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- TODO: If you scroll down long enough this leaks memory
	self._promiseSearchCatalog = MemorizeUtils.memoize(function(params)
		return AvatarEditorUtils.promiseSearchCatalog(params)
			:Then(function(catalogPages)
				return PagesProxy.new(catalogPages)
			end)
	end)

	self._assetAggregator = self._maid:Add(Aggregator.new("AvatarEditorUtils.promiseBatchItemDetails", function(itemIds)
		return AvatarEditorUtils.promiseBatchItemDetails(itemIds, Enum.AvatarItemType.Asset)
	end))
	self._assetAggregator:SetMaxBatchSize(100)

	self._bundleAggregator = self._maid:Add(Aggregator.new("AvatarEditorUtils.promiseBatchItemDetails", function(itemIds)
		return AvatarEditorUtils.promiseBatchItemDetails(itemIds, Enum.AvatarItemType.Bundle)
	end))
	self._bundleAggregator:SetMaxBatchSize(100)
end

function CatalogSearchServiceCache:PromiseAvatarRules()
	if self._avatarRulesPromise then
		return self._avatarRulesPromise
	end

	self._avatarRulesPromise = AvatarEditorUtils.promiseAvatarRules()
	return self._avatarRulesPromise
end

function CatalogSearchServiceCache:PromiseItemDetails(assetId, avatarItemType)
	if avatarItemType == Enum.AvatarItemType.Asset then
		return self._assetAggregator:Promise(assetId)
	elseif avatarItemType == Enum.AvatarItemType.Bundle then
		return self._bundleAggregator:Promise(assetId)
	else
		error("Unknown avatarItemType")
	end
end

function CatalogSearchServiceCache:PromiseSearchCatalog(params)
	return self._promiseSearchCatalog(params)
		:Then(function(pagesProxy)
			return pagesProxy:Clone()
		end)
end

function CatalogSearchServiceCache:Destroy()
	self._maid:DoCleaning()
end

return CatalogSearchServiceCache