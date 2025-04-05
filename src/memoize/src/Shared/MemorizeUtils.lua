--!strict
--[=[
	@class MemorizeUtils
]=]

local require = require(script.Parent.loader).load(script)

local LRUCache = require("LRUCache")
local Tuple = require("Tuple")
local TupleLookup = require("TupleLookup")
local TypeUtils = require("TypeUtils")

local MemorizeUtils = {}

export type CacheConfig = {
	maxSize: number,
}

--[=[
	Memoizes a function with a max size

	@param func function
	@param cacheConfig CacheConfig
]=]
function MemorizeUtils.memoize<T..., U...>(func: (T...) -> U..., cacheConfig: CacheConfig?): (T...) -> U...
	assert(type(func) == "function", "Bad func")
	assert(MemorizeUtils.isCacheConfig(cacheConfig) or cacheConfig == nil, "Bad cacheConfig")

	local config = cacheConfig or MemorizeUtils.createCacheConfig()

	local tupleLookup = TupleLookup.new()
	local cache = LRUCache.new(config.maxSize)

	return function(...: T...): U...
		-- O(n)
		local params = tupleLookup:ToTuple(TypeUtils.anyValue(...))

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
function MemorizeUtils.isCacheConfig(value: any): boolean
	return type(value) == "table" and type(value.maxSize) == "number"
end

--[=[
	Creates a new cache config

	@param cacheConfig table | nil
	@return CacheConfig
]=]
function MemorizeUtils.createCacheConfig(cacheConfig: CacheConfig?): CacheConfig
	assert(MemorizeUtils.isCacheConfig(cacheConfig) or cacheConfig == nil, "Bad cacheConfig")


	return {
		maxSize = if cacheConfig and cacheConfig.maxSize then cacheConfig.maxSize else 128;
	}
end

return MemorizeUtils