--[=[
	@class CatalogSearchServiceCache
]=]

local require = require(script.Parent.loader).load(script)

local MemorizeUtils = require("MemorizeUtils")
local AvatarEditorUtils = require("AvatarEditorUtils")

local CatalogSearchServiceCache = {}
CatalogSearchServiceCache.ServiceName = "CatalogSearchServiceCache"

function CatalogSearchServiceCache:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._promiseSearchCatalog = MemorizeUtils.memoize(function(params)
		return AvatarEditorUtils.promiseSearchCatalog(params)
	end)

	self._promiseInventoryPages = MemorizeUtils.memoize(function(avatarAssetTypes)
		return AvatarEditorUtils.promiseInventoryPages(avatarAssetTypes)
	end)
end

function CatalogSearchServiceCache:PromiseAvatarRules()
	if self._avatarRulesPromise then
		return self._avatarRulesPromise
	end

	self._avatarRulesPromise = AvatarEditorUtils.promiseAvatarRules()
	return self._avatarRulesPromise
end

function CatalogSearchServiceCache:PromiseSearchCatalog(params)
	return self._promiseSearchCatalog(params)
end

function CatalogSearchServiceCache:PromiseInventoryPages(avatarAssetTypes)
	return self._promiseInventoryPages(avatarAssetTypes)
end

return CatalogSearchServiceCache