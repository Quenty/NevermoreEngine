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

end


function CatalogSearchServiceCache:PromiseSearchCatalog(params)
	return self._promiseSearchCatalog(params)
end


return CatalogSearchServiceCache