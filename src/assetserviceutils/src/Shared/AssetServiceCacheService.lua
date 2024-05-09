--[=[
	@class AssetServiceCacheService
]=]

local require = require(script.Parent.loader).load(script)

local MemorizeUtils = require("MemorizeUtils")
local AssetServiceUtils = require("AssetServiceUtils")

local AssetServiceCacheService = {}
AssetServiceCacheService.ServiceName = "AssetServiceCacheService"

function AssetServiceCacheService:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self:_ensureInit()
end

function AssetServiceCacheService:PromiseBundleDetails(bundleId)
	assert(type(bundleId) == "number", "Bad bundleId")

	self:_ensureInit()

	return self._promiseBundleDetails(bundleId)
end

function AssetServiceCacheService:_ensureInit()
	if self._promiseBundleDetails then
		return
	end

	self._promiseBundleDetails = MemorizeUtils.memoize(AssetServiceUtils.promiseBundleDetails)
end

return AssetServiceCacheService