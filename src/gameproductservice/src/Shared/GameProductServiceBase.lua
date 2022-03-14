--[=[
	@class GameProductServiceBase
]=]

local require = require(script.Parent.loader).load(script)

local promiseBoundClass = require("promiseBoundClass")
local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")

local GameProductServiceBase = {}
GameProductServiceBase.ClassName = "GameProductServiceBase"
GameProductServiceBase.__index = GameProductServiceBase

function GameProductServiceBase.new()
	local self = setmetatable({}, GameProductServiceBase)

	return self
end

function GameProductServiceBase:GetPlayerProductManagerBinder()
	error("Not implemented")
end

function GameProductServiceBase:ObservePlayerOwnsPass(player, gamePassId)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(gamePassId) == "number", "Bad gamePassId")

	return self:_observeManager(player):Pipe({
		Rx.switchMap(function(manager)
			if manager then
				return manager:ObservePlayerOwnsPass(gamePassId)
			else
				return Rx.of(false)
			end
		end)
	})
end

function GameProductServiceBase:PromisePlayerOwnsPass(player, gamePassId)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(gamePassId) == "number", "Bad gamePassId")

	return self:_promiseManager(player)
		:Then(function(manager)
			return manager:PromisePlayerOwnsPass(gamePassId)
		end)
end

function GameProductServiceBase:PromptGamePassPurchase(player, gamePassId)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(gamePassId) == "number", "Bad gamePassId")

	return self:_promiseManager(player)
		:Then(function(manager)
			return manager:PromptGamePassPurchase(gamePassId)
		end)
end

function GameProductServiceBase:PromisePromptPurchase(player, productId)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(productId) == "number", "Bad productId")

	return self:_promiseManager(player)
		:Then(function(manager)
			return manager:PromisePromptPurchase(productId)
		end)
end


function GameProductServiceBase:_observeManager(player)
	assert(typeof(player) == "Instance", "Bad player")

	return RxBinderUtils.observeBoundClass(self:GetPlayerProductManagerBinder(), player)
end

function GameProductServiceBase:_promiseManager(player)
	assert(typeof(player) == "Instance", "Bad player")

	return promiseBoundClass(self:GetPlayerProductManagerBinder(), player)
end


return GameProductServiceBase