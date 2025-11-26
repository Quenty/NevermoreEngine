--[=[
	Constructing a new rogue property/rogue property table can be expensive.
	This caches it so frame-usage is cheap.

	@class RoguePropertyCacheService
]=]

local require = require(script.Parent.loader).load(script)
local RunService = game:GetService("RunService")

local RoguePropertyCache = require("RoguePropertyCache")
local ServiceBag = require("ServiceBag")

local RoguePropertyCacheService = {}
RoguePropertyCacheService.ServiceName = "RoguePropertyCacheService"

local WEAK_K_TABLE = { __mode = "k" }

function RoguePropertyCacheService:Init(serviceBag: ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._cache = setmetatable({}, WEAK_K_TABLE)
end

function RoguePropertyCacheService:GetCache(roguePropertyDefinition)
	if not self._cache then
		assert(not RunService:IsRunning(), "Not in test mode")
		-- Test mode
		return RoguePropertyCache.new(roguePropertyDefinition:GetName())
	end

	if self._cache[roguePropertyDefinition] then
		return self._cache[roguePropertyDefinition]
	end

	local cache = RoguePropertyCache.new(roguePropertyDefinition:GetName())
	self._cache[roguePropertyDefinition] = cache
	return cache
end

return RoguePropertyCacheService
