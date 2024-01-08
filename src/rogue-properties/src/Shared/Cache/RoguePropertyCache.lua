--[=[
	@class RoguePropertyCache
]=]

local require = require(script.Parent.loader).load(script)

local RoguePropertyCache = {}
RoguePropertyCache.ClassName = "RoguePropertyCache"
RoguePropertyCache.__index = RoguePropertyCache

function RoguePropertyCache.new()
	local self = setmetatable({}, RoguePropertyCache)

	self._cache = setmetatable({}, {__mode="v"})

	return self
end

function RoguePropertyCache:Store(adornee, roguePropertyTable)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	self._cache[adornee] = roguePropertyTable
end

function RoguePropertyCache:Find(adornee)
	assert(typeof(adornee) == "Instance", "Bad adornee")

	return self._cache[adornee]
end

return RoguePropertyCache