--[=[
	@class GameProductServiceBase
]=]

local require = require(script.Parent.loader).load(script)

local promiseBoundClass = require("promiseBoundClass")
local Rx = require("Rx")
local RxBinderUtils = require("RxBinderUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local Promise = require("Promise")
local RxStateStackUtils = require("RxStateStackUtils")

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

function GameProductServiceBase:ObservePlayerOwnsPass(player, passIdOrKey)
	assert(typeof(player) == "Instance", "Bad player")

	if type(passIdOrKey) == "string" then
		local picker = self._gameConfigService:GetConfigPicker()
		return picker:ObserveActiveAssetOfAssetTypeAndKeyBrio(GameConfigAssetTypes.PASS, passIdOrKey)
			:Pipe({
				RxStateStackUtils.topOfStack();
				Rx.switchMap(function(asset)
					if asset then
						return asset:ObserveAssetId()
					else
						return Rx.of(nil)
					end
				end);
				Rx.switchMap(function(assetId)
					if assetId then
						return self:_observePlayerOwnsPassForId(player, assetId)
					else
						warn(("No pass with key %q"):format(tostring(passIdOrKey)))
						return Rx.of(false)
					end
				end)
			})
	elseif type(passIdOrKey) == "number" then
		return self:_observePlayerOwnsPassForId(player, passIdOrKey)
	else
		error("[GameProductServiceBase.ObservePlayerOwnsPass] - Bad passIdOrKey")
	end
end

function GameProductServiceBase:_observePlayerOwnsPassForId(player, passId)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(passId) == "number", "Bad passId")

	return self:_observeManager(player):Pipe({
		Rx.switchMap(function(manager)
			if manager then
				return manager:ObservePlayerOwnsPass(passId)
			else
				return Rx.of(false)
			end
		end)
	})
end

function GameProductServiceBase:PromisePlayerOwnsPass(player, passIdOrKey)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(passIdOrKey) == "number" or type(passIdOrKey) == "string", "Bad passIdOrKey")

	local passId = self:ToAssetId(GameConfigAssetTypes.PASS, passIdOrKey)
	if not passId then
		return Promise.rejected(("No pass with key %q"):format(tostring(passIdOrKey)))
	end

	return self:_promiseManager(player)
		:Then(function(manager)
			return manager:PromisePlayerOwnsPass(passId)
		end)
end

function GameProductServiceBase:PromptGamePassPurchase(player, passIdOrKey)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(passIdOrKey) == "number" or type(passIdOrKey) == "string", "Bad passIdOrKey")

	local passId = self:ToAssetId(GameConfigAssetTypes.PASS, passIdOrKey)
	if not passId then
		return Promise.rejected(("No pass with key %q"):format(tostring(passIdOrKey)))
	end

	return self:_promiseManager(player)
		:Then(function(manager)
			return manager:PromptGamePassPurchase(passId)
		end)
end

function GameProductServiceBase:PromisePromptPurchase(player, productIdOrKey)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(productIdOrKey) == "number", "Bad productIdOrKey")

	local productId = self:ToAssetId(GameConfigAssetTypes.PRODUCT, productIdOrKey)
	if not productId then
		return Promise.rejected(("No product with key %q"):format(tostring(productIdOrKey)))
	end

	return self:_promiseManager(player)
		:Then(function(manager)
			return manager:PromisePromptPurchase(productId)
		end)
end

function GameProductServiceBase:ToAssetId(assetType, assetIdOrKey)
	assert(type(assetIdOrKey) == "number" or type(assetIdOrKey) == "string", "Bad assetIdOrKey")

	if type(assetIdOrKey) == "string" then
		local picker = self._gameConfigService:GetConfigPicker()
		local asset = picker:FindFirstActiveAssetOfKey(assetType, assetIdOrKey)
		if asset then
			return asset:GetAssetId()
		else
			return nil
		end
	end

	return assetIdOrKey
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