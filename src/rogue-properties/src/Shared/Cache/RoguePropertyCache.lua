--!strict
--[=[
	Utility class that helps cache rogue properties per an instance

	@class RoguePropertyCache
]=]

local WEAK_KV = { __mode = "kv" }

local RoguePropertyCache = {}
RoguePropertyCache.ClassName = "RoguePropertyCache"
RoguePropertyCache.__index = RoguePropertyCache

-- A cached entry is either a RogueProperty or a RoguePropertyTable. Those types
-- form a require cycle with this module (Definition -> CacheService -> ... ->
-- Property/Table -> Definition), so the cache stores them structurally as `any`.
export type RoguePropertyCache = typeof(setmetatable(
	{} :: {
		_debugName: string,
		_cache: { [Instance]: any },
	},
	{} :: typeof({ __index = RoguePropertyCache })
))

function RoguePropertyCache.new(debugName: string): RoguePropertyCache
	local self: RoguePropertyCache = setmetatable({} :: any, RoguePropertyCache)

	self._debugName = debugName
	self._cache = setmetatable({}, WEAK_KV) :: any

	return self
end

--[=[
	Caches the implementation for a given instance

	@param adornee Instance
	@param roguePropertyTable RoguePropertyTable
]=]
function RoguePropertyCache.Store(self: RoguePropertyCache, adornee: Instance, roguePropertyTable: any)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	self._cache[adornee] = roguePropertyTable
end

--[=[
	Retrieves the cached item

	@param adornee Instance
	@return RoguePropertyTable
]=]
function RoguePropertyCache.Find(self: RoguePropertyCache, adornee: Instance): any
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self._cache[adornee]
end

return RoguePropertyCache
