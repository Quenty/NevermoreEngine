--[=[
	Utility class that helps cache rogue properties per an instance

	@class RoguePropertyCache
]=]

local WEAK_KV = { __mode = "kv" }

local RoguePropertyCache = {}
RoguePropertyCache.ClassName = "RoguePropertyCache"
RoguePropertyCache.__index = RoguePropertyCache

function RoguePropertyCache.new(debugName: string)
	local self = setmetatable({}, RoguePropertyCache)

	self._debugName = debugName
	self._cache = setmetatable({}, WEAK_KV)

	return self
end

--[=[
	Caches the implementation for a given instance

	@param adornee Instance
	@param roguePropertyTable RoguePropertyTable
]=]
function RoguePropertyCache:Store(adornee: Instance, roguePropertyTable)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	self._cache[adornee] = roguePropertyTable
end

--[=[
	Retrieves the cached item

	@param adornee Instance
	@return RoguePropertyTable
]=]
function RoguePropertyCache:Find(adornee: Instance)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self._cache[adornee]
end

return RoguePropertyCache
