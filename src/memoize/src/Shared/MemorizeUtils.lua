--[=[
	@class MemorizeUtils
]=]

local require = require(script.Parent.loader).load(script)

local LRUCache = require("LRUCache")

local MemorizeUtils = {}

--[=[
	Memoizes a function with a max size

	@param func function
	@param cacheConfig CacheConfig
]=]
function MemorizeUtils.memoize(func, cacheConfig)
	assert(type(func) == "function", "Bad func")
	assert(MemorizeUtils.isCacheConfig(cacheConfig) or cacheConfig == nil, "Bad cacheConfig")

	cacheConfig = cacheConfig or MemorizeUtils.createCacheConfig()

	local cache = MemorizeUtils._createCacheNode(cacheConfig)

	return function(...)
		local params = table.pack(...)

		local results = MemorizeUtils._cache_get(cache, params)
		if not results then
			results = table.pack(func(...))
			MemorizeUtils._cache_put(cache, params, results, cacheConfig)
		end

		return unpack(results, 1, results.n)
	end
end

--[=[
	Returns true if a valid cache config

	@param value any
	@return boolean
]=]
function MemorizeUtils.isCacheConfig(value)
	return type(value) == "table" and type(value.maxSize) == "number"
end

--[=[
	Creates a new cache config

	@param cacheConfig table | nil
	@return CacheConfig
]=]
function MemorizeUtils.createCacheConfig(cacheConfig)
	assert(MemorizeUtils.isCacheConfig(cacheConfig) or cacheConfig == nil, "Bad cacheConfig")

	cacheConfig = cacheConfig or {}

	return {
		maxSize = cacheConfig.maxSize or 128;
	}
end

function MemorizeUtils._createCacheNode(cacheConfig)
	return {
		childrenLRUCache = LRUCache.new(cacheConfig.maxSize);
	}
end

function MemorizeUtils._cache_get(cache, params)
	local node = cache
	for i=1, #params do
		node = node.childrenLRUCache:get(params[i])
		if not node then
			return nil
		end
	end

	return node.results
end

function MemorizeUtils._cache_put(cache, params, results, cacheConfig)
	local node = cache

	for i=1, params.n do
		local param = params[i]

		local paramNode = node.childrenLRUCache:get(param)
		if paramNode then
			node = paramNode
		else
			paramNode = MemorizeUtils._createCacheNode(cacheConfig)
			node.childrenLRUCache:set(param, paramNode)
			node = paramNode
		end
	end

	node.results = results
end

return MemorizeUtils