--[=[
	Constructing a new rogue property/rogue property table can be expensive.
	This caches it so frame-usage is cheap.

	@class RoguePropertyCacheService
]=]

local require = require(script.Parent.loader).load(script)
local RunService = game:GetService("RunService")

local RoguePropertyCache = require("RoguePropertyCache")
local _ServiceBag = require("ServiceBag")

local RoguePropertyCacheService = {}
RoguePropertyCacheService.ServiceName = "RoguePropertyCacheService"

function RoguePropertyCacheService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._cache = setmetatable({}, {__mode = "k"})
end

function RoguePropertyCacheService:GetCache(roguePropertyDefinition)
	if not self._cache then
		assert(not RunService:IsRunning(), "Not in test mode")
		-- Test mode
		return RoguePropertyCache.new()
	end

	if self._cache[roguePropertyDefinition] then
		return self._cache[roguePropertyDefinition]
	end

	local cache = RoguePropertyCache.new()
	self._cache[roguePropertyDefinition] = cache
	return cache
end

return RoguePropertyCacheService