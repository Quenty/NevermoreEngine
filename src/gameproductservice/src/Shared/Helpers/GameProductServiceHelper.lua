--[=[
	Helper that is used for each game product service. See [GameProductService].

	@class GameProductServiceHelper
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local promiseBoundClass = require("promiseBoundClass")
local RxBinderUtils = require("RxBinderUtils")
local RxBrioUtils = require("RxBrioUtils")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local RxStateStackUtils = require("RxStateStackUtils")
local Promise = require("Promise")
local Rx = require("Rx")

local GameProductServiceHelper = setmetatable({}, BaseObject)
GameProductServiceHelper.ClassName = "GameProductServiceHelper"
GameProductServiceHelper.__index = GameProductServiceHelper

--[=[
	Helper to observe state for the game product service

	@param playerProductManagerBinder Binder<PlayerProductManager>
]=]
function GameProductServiceHelper.new(playerProductManagerBinder)
	local self = setmetatable(BaseObject.new(), GameProductServiceHelper)

	self._playerProductManagerBinder = assert(playerProductManagerBinder, "Bad playerProductManagerBinder")

	return self
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return boolean
]=]
function GameProductServiceHelper:HasPlayerPurchasedThisSession(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	local marketeer = self:_getPlayerMarketeer(player)
	if not marketeer then
		warn("[GameProductServiceHelper.HasPlayerPurchasedThisSession] - Failed to find marketeer for player")
		return false
	end

	local assetTracker = marketeer:GetAssetTrackerOrError(assetType)
	return assetTracker:HasPurchasedThisSession(idOrKey)
end

--[=[
	Prompts the user to purchase the asset, and returns true if purchased

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductServiceHelper:PromisePromptPurchase(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_promisePlayerMarketeer(player)
		:Then(function(marketeer)
			local assetTracker = marketeer:GetAssetTrackerOrError(assetType)
			return assetTracker:PromisePromptPurchase(idOrKey)
		end)
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductServiceHelper:PromisePlayerOwnership(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_promisePlayerMarketeer(player)
		:Then(function(marketeer)
			local ownershipTracker = marketeer:GetOwnershipTrackerOrError(assetType)
			return ownershipTracker:PromiseOwnsAsset(idOrKey)
		end)
end

--[=[
	Returns true if item has been purchased this session

	@param player Player
	@param assetType GameConfigAssetType
	@return Promise<boolean>
]=]
function GameProductServiceHelper:PromiseIsOwnable(player, assetType)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	return self:_promisePlayerMarketeer(player)
		:Then(function(marketeer)
			return marketeer:IsOwnable(assetType)
		end)
end

--[=[
	Promises the player prompt as opened

	@param player Player
	@return Promise<boolean>
]=]
function GameProductServiceHelper:PromisePlayerIsPromptOpen(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:_promisePlayerMarketeer(player)
		:Then(function(marketeer)
			return marketeer:IsPromptOpen()
		end)
end

--[=[
	Promises the player prompt as opened

	@param player Player
	@return Promise<boolean>
]=]
function GameProductServiceHelper:PromisePlayerPromptClosed(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:_promisePlayerMarketeer(player)
		:Then(function(marketeer)
			return marketeer:PromisePlayerPromptClosed()
		end)
end

--[=[
	Observes player ownership

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductServiceHelper:ObservePlayerOwnership(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	-- TODO: Maybe make this more light weight and cache
	return self:_observePlayerProductManagerBrio(player):Pipe({
		RxBrioUtils.switchMapBrio(function(playerProductManager)
			local marketeer = playerProductManager:GetMarketeer()
			local ownershipTracker = marketeer:GetOwnershipTrackerOrError(assetType)
			return ownershipTracker:ObserveOwnsAsset(idOrKey)
		end);
		RxStateStackUtils.topOfStack(false);
	})
end

--[=[
	Fires when the specified player purchases an asset

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<>
]=]
function GameProductServiceHelper:ObservePlayerAssetPurchased(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_observePlayerProductManagerBrio(player):Pipe({
		RxBrioUtils.switchMapBrio(function(playerProductManager)
			local marketeer = playerProductManager:GetMarketeer()
			local ownershipTracker = marketeer:GetOwnershipTrackerOrError(assetType)
			return ownershipTracker:ObserveAssetPurchased(idOrKey)
		end);
		Rx.map(function(_brio)
			return true
		end)
	})
end

--[=[
	Fires when any player purchases an asset

	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Observable<Player>
]=]
function GameProductServiceHelper:ObserveAssetPurchased(assetType, idOrKey)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self._playerProductManagerBinder:ObserveAllBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(playerProductManager)
			local marketeer = playerProductManager:GetMarketeer()
			local assetTracker = marketeer:GetAssetTrackerOrError(assetType)
			return assetTracker:ObserveAssetPurchased(idOrKey):Pipe({
				Rx.map(function()
					return playerProductManager:GetPlayer()
				end);
			})
		end);
		Rx.map(function(brio)
			-- I THINK THIS LEAKS
			if brio:IsDead() then
				return nil
			end

			return brio:GetValue()
		end);
		Rx.where(function(value)
			return value ~= nil
		end);
	})
end

--[=[
	Checks if the asset is ownable and if it is, checks player ownership. Otherwise, it checks if the asset
	has been purchased this session. If the asset has not been purchased this session it prompts the user to
	purchase the item.

	@param player Player
	@param assetType GameConfigAssetType
	@param idOrKey string | number
	@return Promise<boolean>
]=]
function GameProductServiceHelper:PromisePlayerOwnershipOrPrompt(player, assetType, idOrKey)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return self:_promisePlayerMarketeer(player)
		:Then(function(marketeer)
			local assetTracker = marketeer:GetAssetTrackerOrError(assetType)

			if marketeer:IsOwnable(assetType) then
				-- Retrieve ownership
				local ownershipTracker = marketeer:GetOwnershipTrackerOrError(assetType)
				return ownershipTracker:PromiseOwnsAsset(idOrKey)
					:Then(function(ownsAsset)
						if ownsAsset then
							return true
						else
							return assetTracker:PromisePromptPurchase(idOrKey)
						end
					end)
			else
				-- Assume this is a single session purchase
				if assetTracker:HasPurchasedThisSession(idOrKey) then
					return Promise.resolved(true)
				end

				return assetTracker:PromisePromptPurchase(idOrKey)
			end
		end)
end

function GameProductServiceHelper:_observePlayerProductManagerBrio(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return RxBinderUtils.observeBoundClassBrio(self._playerProductManagerBinder, player)
end

function GameProductServiceHelper:_promisePlayerProductManager(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return promiseBoundClass(self._playerProductManagerBinder, player)
end

function GameProductServiceHelper:_promisePlayerMarketeer(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:_promisePlayerProductManager(player)
		:Then(function(productManager)
			return productManager:GetMarketeer()
		end)
end

function GameProductServiceHelper:_getPlayerProductManager(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self._playerProductManagerBinder:Get(player)
end

function GameProductServiceHelper:_getPlayerMarketeer(player)
	local productManager = self:_getPlayerProductManager(player)
	if productManager then
		return productManager:GetMarketeer()
	else
		return nil
	end
end

return GameProductServiceHelper