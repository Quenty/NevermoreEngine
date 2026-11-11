--!strict
--[=[
	@class CatalogSearchServiceCache
]=]

local require = require(script.Parent.loader).load(script)

local Aggregator = require("Aggregator")
local AvatarEditorUtils = require("AvatarEditorUtils")
local Maid = require("Maid")
local MemorizeUtils = require("MemorizeUtils")
local PagesProxy = require("PagesProxy")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local CatalogSearchServiceCache = {}
CatalogSearchServiceCache.ServiceName = "CatalogSearchServiceCache"

export type CatalogSearchServiceCache = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_serviceBag: ServiceBag.ServiceBag,
		_promiseSearchCatalog: any,
		_assetAggregator: Aggregator.Aggregator<{ AvatarEditorUtils.AvatarItemDetails }>,
		_bundleAggregator: Aggregator.Aggregator<{ AvatarEditorUtils.AvatarItemDetails }>,
		_avatarRulesPromise: Promise.Promise<AvatarEditorUtils.AvatarRules>?,
	},
	{} :: typeof({ __index = CatalogSearchServiceCache })
))

function CatalogSearchServiceCache.Init(self: CatalogSearchServiceCache, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- TODO: If you scroll down long enough this leaks memory
	self._promiseSearchCatalog = MemorizeUtils.memoize(function(params: CatalogSearchParams)
		return AvatarEditorUtils.promiseSearchCatalog(params):Then(function(catalogPages)
			return PagesProxy.new(catalogPages)
		end)
	end)

	self._assetAggregator =
		self._maid:Add(Aggregator.new("AvatarEditorUtils.promiseBatchItemDetails", function(itemIds: { number })
			return AvatarEditorUtils.promiseBatchItemDetails(itemIds, Enum.AvatarItemType.Asset)
		end))
	self._assetAggregator:SetMaxBatchSize(100)

	self._bundleAggregator =
		self._maid:Add(Aggregator.new("AvatarEditorUtils.promiseBatchItemDetails", function(itemIds: { number })
			return AvatarEditorUtils.promiseBatchItemDetails(itemIds, Enum.AvatarItemType.Bundle)
		end))
	self._bundleAggregator:SetMaxBatchSize(100)
end

function CatalogSearchServiceCache.PromiseAvatarRules(
	self: CatalogSearchServiceCache
): Promise.Promise<AvatarEditorUtils.AvatarRules>
	if self._avatarRulesPromise then
		return self._avatarRulesPromise
	end

	local promise = AvatarEditorUtils.promiseAvatarRules() :: Promise.Promise<AvatarEditorUtils.AvatarRules>
	self._avatarRulesPromise = promise
	return promise
end

function CatalogSearchServiceCache.PromiseItemDetails(
	self: CatalogSearchServiceCache,
	assetId: number,
	avatarItemType: Enum.AvatarItemType
): Promise.Promise<{ AvatarEditorUtils.AvatarItemDetails }>
	if avatarItemType == Enum.AvatarItemType.Asset then
		return self._assetAggregator:Promise(assetId)
	elseif avatarItemType == Enum.AvatarItemType.Bundle then
		return self._bundleAggregator:Promise(assetId)
	else
		error("Unknown avatarItemType")
	end
end

function CatalogSearchServiceCache.PromiseSearchCatalog(
	self: CatalogSearchServiceCache,
	params: CatalogSearchParams
): Promise.Promise<PagesProxy.PagesProxy>
	return (self._promiseSearchCatalog :: any)(params):Then(
			function(pagesProxy: PagesProxy.PagesProxy)
				return pagesProxy:Clone()
			end
		) :: Promise.Promise<PagesProxy.PagesProxy>
end

function CatalogSearchServiceCache.Destroy(self: CatalogSearchServiceCache): ()
	self._maid:DoCleaning()
end

return CatalogSearchServiceCache
