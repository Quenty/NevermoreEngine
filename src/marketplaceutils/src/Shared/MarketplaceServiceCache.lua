--[=[
	@class MarketplaceServiceCache
]=]

local require = require(script.Parent.loader).load(script)

local MemorizeUtils = require("MemorizeUtils")
local MarketplaceUtils = require("MarketplaceUtils")
local _ServiceBag = require("ServiceBag")

local MarketplaceServiceCache = {}
MarketplaceServiceCache.ServiceName = "MarketplaceServiceCache"

function MarketplaceServiceCache:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self:_ensureInit()
end

function MarketplaceServiceCache:PromiseProductInfo(productId: number, infoType: Enum.InfoType)
	assert(type(productId) == "number", "Bad productId")

	self:_ensureInit()

	return self._promiseProductInfo(productId, infoType)
end

function MarketplaceServiceCache:_ensureInit()
	if self._promiseProductInfo then
		return
	end

	self._promiseProductInfo = MemorizeUtils.memoize(MarketplaceUtils.promiseProductInfo, {
		maxSize = 2048;
	})
end

return MarketplaceServiceCache