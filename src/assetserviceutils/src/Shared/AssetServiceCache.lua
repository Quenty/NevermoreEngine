--[=[
	@class AssetServiceCache
]=]

local require = require(script.Parent.loader).load(script)

local MemorizeUtils = require("MemorizeUtils")
local AssetServiceUtils = require("AssetServiceUtils")
local _ServiceBag = require("ServiceBag")

local AssetServiceCache = {}
AssetServiceCache.ServiceName = "AssetServiceCache"

function AssetServiceCache:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self:_ensureInit()
end

function AssetServiceCache:PromiseBundleDetails(bundleId: number)
	assert(type(bundleId) == "number", "Bad bundleId")

	self:_ensureInit()

	return self._promiseBundleDetails(bundleId)
end

function AssetServiceCache:_ensureInit()
	if self._promiseBundleDetails then
		return
	end

	self._promiseBundleDetails = MemorizeUtils.memoize(AssetServiceUtils.promiseBundleDetails)
end

return AssetServiceCache