--!strict
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

export type RoguePropertyDefinitionLike = {
	GetName: (self: RoguePropertyDefinitionLike) -> string,
}

export type RoguePropertyCacheService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_cache: { [RoguePropertyDefinitionLike]: RoguePropertyCache.RoguePropertyCache<any> }?,
	},
	{} :: typeof({ __index = RoguePropertyCacheService })
))

function RoguePropertyCacheService.Init(self: RoguePropertyCacheService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._cache = setmetatable({}, WEAK_K_TABLE) :: any
end

function RoguePropertyCacheService.GetCache(
	self: RoguePropertyCacheService,
	roguePropertyDefinition: RoguePropertyDefinitionLike
): RoguePropertyCache.RoguePropertyCache<any>
	local cache = self._cache
	if not cache then
		assert(not RunService:IsRunning(), "Not in test mode")
		-- Test mode
		return RoguePropertyCache.new(roguePropertyDefinition:GetName())
	end

	local existing = cache[roguePropertyDefinition]
	if existing then
		return existing
	end

	local newCache = RoguePropertyCache.new(roguePropertyDefinition:GetName())
	cache[roguePropertyDefinition] = newCache
	return newCache
end

return RoguePropertyCacheService
