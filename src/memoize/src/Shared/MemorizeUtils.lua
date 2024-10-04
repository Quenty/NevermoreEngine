--[=[
	@class MemorizeUtils
]=]

local require = require(script.Parent.loader).load(script)

local LRUCache = require("LRUCache")
local Tuple = require("Tuple")
local TupleLookup = require("TupleLookup")

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

	local tupleLookup = TupleLookup.new()
	local cache = LRUCache.new(cacheConfig.maxSize)

	return function(...)
		-- O(n)
		local params = tupleLookup:ToTuple(...)

		local found = cache:get(params)
		if found then
			return found:Unpack()
		end

		local result = Tuple.new(func(...))
		cache:set(params, result)

		return result:Unpack()
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

return MemorizeUtils