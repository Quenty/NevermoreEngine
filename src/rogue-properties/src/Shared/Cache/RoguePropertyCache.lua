--!strict
--[=[
	Utility class that helps cache rogue properties per an instance

	@class RoguePropertyCache
]=]

local WEAK_KV = { __mode = "kv" }

local RoguePropertyCache = {}
RoguePropertyCache.ClassName = "RoguePropertyCache"
RoguePropertyCache.__index = RoguePropertyCache

export type RoguePropertyCache<T> = typeof(setmetatable(
	{} :: {
		_debugName: string,
		_cache: { [Instance]: T },
	},
	{} :: typeof({ __index = RoguePropertyCache })
))

function RoguePropertyCache.new<T>(debugName: string): RoguePropertyCache<T>
	local self: RoguePropertyCache<T> = setmetatable({} :: any, RoguePropertyCache)

	self._debugName = debugName
	self._cache = setmetatable({}, WEAK_KV) :: any

	return self
end

--[=[
	Caches the implementation for a given instance

	@param adornee Instance
	@param roguePropertyTable RoguePropertyTable
]=]
function RoguePropertyCache.Store<T>(self: RoguePropertyCache<T>, adornee: Instance, roguePropertyTable: T): ()
	assert(typeof(adornee) == "Instance", "Bad adornee")

	self._cache[adornee] = roguePropertyTable
end

--[=[
	Retrieves the cached item

	@param adornee Instance
	@return RoguePropertyTable
]=]
function RoguePropertyCache.Find<T>(self: RoguePropertyCache<T>, adornee: Instance): T?
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self._cache[adornee]
end

return RoguePropertyCache
