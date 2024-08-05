--[=[
	@class MarketplaceServiceCache
]=]

local require = require(script.Parent.loader).load(script)

local MemorizeUtils = require("MemorizeUtils")
local MarketplaceUtils = require("MarketplaceUtils")

local MarketplaceServiceCache = {}
MarketplaceServiceCache.ServiceName = "MarketplaceServiceCache"

function MarketplaceServiceCache:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self:_ensureInit()
end

function MarketplaceServiceCache:PromiseProductInfo(productId, infoType)
	assert(type(productId) == "number", "Bad productId")

	self:_ensureInit()

	return self._promiseProductInfo(productId, infoType)
end

function MarketplaceServiceCache:_ensureInit()
	if self._promiseProductInfo then
		return
	end

	self._promiseProductInfo = MemorizeUtils.memoize(MarketplaceUtils.promiseProductInfo)
end

return MarketplaceServiceCache