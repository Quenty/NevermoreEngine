--!strict
--[=[
	@class MarketplaceServiceCache
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceUtils = require("MarketplaceUtils")
local MemorizeUtils = require("MemorizeUtils")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")

local MarketplaceServiceCache = {}
MarketplaceServiceCache.ServiceName = "MarketplaceServiceCache"

export type MarketplaceServiceCache = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_promiseProductInfo: (
			productId: number,
			infoType: Enum.InfoType
		) -> Promise.Promise<MarketplaceUtils.AssetProductInfo | MarketplaceUtils.GamePassOrDeveloperProductInfo>,
	},
	{} :: typeof({ __index = MarketplaceServiceCache })
))

function MarketplaceServiceCache.Init(self: MarketplaceServiceCache, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self:_ensureInit()
end

function MarketplaceServiceCache.PromiseProductInfo(
	self: MarketplaceServiceCache,
	productId: number,
	infoType: Enum.InfoType
): Promise.Promise<
	MarketplaceUtils.AssetProductInfo | MarketplaceUtils.GamePassOrDeveloperProductInfo
>
	assert(type(productId) == "number", "Bad productId")

	self:_ensureInit()

	return self._promiseProductInfo(productId, infoType)
end

function MarketplaceServiceCache._ensureInit(self: MarketplaceServiceCache): ()
	if self._promiseProductInfo then
		return
	end

	self._promiseProductInfo = MemorizeUtils.memoize(MarketplaceUtils.promiseProductInfo, {
		maxSize = 2048,
	})
end

return MarketplaceServiceCache
