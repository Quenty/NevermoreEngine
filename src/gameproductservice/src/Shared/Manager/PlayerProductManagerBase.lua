--[=[
	@class PlayerProductManagerBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local MarketplaceUtils = require("MarketplaceUtils")
local Promise = require("Promise")
local Rx = require("Rx")
local RxStateStackUtils = require("RxStateStackUtils")
local RxAttributeUtils = require("RxAttributeUtils")
local PlayerProductManagerUtils = require("PlayerProductManagerUtils")
local Maid = require("Maid")

local PlayerProductManagerBase = setmetatable({}, BaseObject)
PlayerProductManagerBase.ClassName = "PlayerProductManagerBase"
PlayerProductManagerBase.__index = PlayerProductManagerBase

function PlayerProductManagerBase.new(player)
	local self = setmetatable(BaseObject.new(player), PlayerProductManagerBase)

	return self
end

--[=[
	Gets the current player
	@return Player
]=]
function PlayerProductManagerBase:GetPlayer()
	return self._obj
end

function PlayerProductManagerBase:GetConfigPicker()
	error("Not implemented")
end

function PlayerProductManagerBase:InitOwnershipAttributes()
	local picker = self:GetConfigPicker()

	self._maid:GiveTask(picker:ObserveActiveAssetOfTypeBrio(GameConfigAssetTypes.PASS):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local topMaid = brio:ToMaid()
		local asset = brio:GetValue()

		local lastAttributeName = nil

		topMaid:GiveTask(Rx.combineLatest({
			assetId = asset:ObserveAssetId();
			assetKey = asset:ObserveAssetKey();
		}):Subscribe(function(state)
			topMaid._current = nil

			local maid = Maid.new()
			local attributeName = PlayerProductManagerUtils.toOwnedAttribute(state.assetKey)

			-- Transfer attribute over
			if lastAttributeName then
				if lastAttributeName ~= attributeName then
					self._obj:SetAttribute(attributeName, self._obj:GetAttribute(lastAttributeName))
					self._obj:SetAttribute(lastAttributeName, nil)
				end
			end

			if state.assetId then
				-- Ensure we read the old unnamed name, and transfer it to the new one.
				local unnamedAttribute = PlayerProductManagerUtils.toIdOwnedAttribute(state.assetId)
				if self._obj:GetAttribute(unnamedAttribute) ~= nil and unnamedAttribute ~= attributeName then
					self._obj:SetAttribute(attributeName, self._obj:GetAttribute(unnamedAttribute))
					self._obj:SetAttribute(unnamedAttribute, nil)
				end

				-- Check ownership
				maid:GiveTask(self:PromisePlayerOwnsPass(state.assetId):Then(function(ownsPass)
					self._obj:SetAttribute(attributeName, ownsPass)
				end))
			else
				-- Initialize the attribute
				if self._obj:GetAttribute(attributeName) == nil then
					self._obj:SetAttribute(attributeName, false)
				end
			end

			lastAttributeName = attributeName
			topMaid._current = maid
		end))
	end))
end

function PlayerProductManagerBase:_getPlayerOwnsPassAttributeName(gamePassId)
	assert(type(gamePassId) == "number", "Bad gamePassId")

	local picker = self:GetConfigPicker()
	local asset = picker:FindFirstActiveAssetOfId(GameConfigAssetTypes.PASS, gamePassId)

	if asset then
		return PlayerProductManagerUtils.toOwnedAttribute(asset:GetAssetKey())
	else
		return PlayerProductManagerUtils.toIdOwnedAttribute(gamePassId)
	end
end

function PlayerProductManagerBase:_observeGamePassOwnedAttributeName(gamePassId)
	assert(type(gamePassId) == "number", "Bad gamePassId")
	local picker = self:GetConfigPicker()

	return picker:ObserveActiveAssetOfAssetTypeAndIdBrio(GameConfigAssetTypes.PASS, gamePassId)
		:Pipe({
			RxStateStackUtils.topOfStack();
			Rx.switchMap(function(latestAsset)
				if latestAsset then
					return latestAsset:ObserveAssetKey()
						:Pipe({
							Rx.map(PlayerProductManagerUtils.toOwnedAttribute)
						})
				else
					return Rx.of(PlayerProductManagerUtils.toIdOwnedAttribute(gamePassId))
				end
			end);
			Rx.distinct();
		})
end

--[=[
	Observes whether the player owns the current pass or not.
	@param gamePassId number
	@return Observable<boolean>
]=]
function PlayerProductManagerBase:ObservePlayerOwnsPass(gamePassId)
	assert(type(gamePassId) == "number", "Bad gamePassId")

	-- Ensure we only emit until first query is done
	return Rx.fromPromise(self:PromisePlayerOwnsPass(gamePassId))
		:Pipe({
			Rx.switchMap(function()
				-- Immediately observe the attribute and attributes
				return self:_observeGamePassOwnedAttributeName(gamePassId):Pipe({
					Rx.switchMap(function(attributeName)
						return RxAttributeUtils.observeAttribute(self._obj, attributeName, false)
					end);
				})
			end);
			Rx.distinct();
		})
end

--[=[
	Promises whether the player owns the current pass or not.
	@param gamePassId number
	@return Promise<boolean>
]=]
function PlayerProductManagerBase:PromisePlayerOwnsPass(gamePassId)
	assert(type(gamePassId) == "number", "Bad gamePassId")

	-- Check cache first (Roblox data model)
	local attributeName = self:_getPlayerOwnsPassAttributeName(gamePassId)
	if self._obj:GetAttribute(attributeName) then
		return Promise.resolved(true)
	end

	-- Query game
	return self._maid:GivePromise(MarketplaceUtils.promiseUserOwnsGamePass(self._obj.UserId, gamePassId))
		:Tap(function(isOwned)
			self:SetPlayerOwnsPass(gamePassId, isOwned)
		end)
end

function PlayerProductManagerBase:SetPlayerOwnsPass(gamePassId, ownsPass)
	assert(type(gamePassId) == "number", "Bad gamePassId")
	assert(type(ownsPass) == "boolean", "Bad ownsPass")

	local attributeName = self:_getPlayerOwnsPassAttributeName(gamePassId)
	self._obj:SetAttribute(attributeName, ownsPass)
end

return PlayerProductManagerBase