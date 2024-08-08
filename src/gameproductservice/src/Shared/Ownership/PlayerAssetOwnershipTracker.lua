--[=[
	This tracking is relatively complicated because we want to track both
	ownership from attributes (can be customized locally), as well as async
	cloud services.

	@class PlayerAssetOwnershipTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local Maid = require("Maid")
local ObservableMapSet = require("ObservableMapSet")
local PlayerAssetOwnershipUtils = require("PlayerAssetOwnershipUtils")
local Promise = require("Promise")
local Rx = require("Rx")
local RxAttributeUtils = require("RxAttributeUtils")
local RxBrioUtils = require("RxBrioUtils")
local RxStateStackUtils = require("RxStateStackUtils")
local ValueObject = require("ValueObject")
local WellKnownAssetOwnershipHandler = require("WellKnownAssetOwnershipHandler")
local ObservableSet = require("ObservableSet")

local PlayerAssetOwnershipTracker = setmetatable({}, BaseObject)
PlayerAssetOwnershipTracker.ClassName = "PlayerAssetOwnershipTracker"
PlayerAssetOwnershipTracker.__index = PlayerAssetOwnershipTracker

function PlayerAssetOwnershipTracker.new(player, configPicker, assetType, marketTracker)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	local self = setmetatable(BaseObject.new(), PlayerAssetOwnershipTracker)

	self._player = assert(player, "No player")
	self._configPicker = assert(configPicker, "No configPicker")
	self._assetType = assert(assetType, "No assetType")
	self._marketTracker = assert(marketTracker, "No marketTracker")

	self._ownershipCallback = self._maid:Add(ValueObject.new(nil))
	self._attributesEnabled = self._maid:Add(ValueObject.new(false, "boolean"))

	self._ownedAssetIdSet = self._maid:Add(ObservableSet.new())
	self._assetIdToWellKnownOwnershipTracker = self._maid:Add(ObservableMapSet.new())
	self._assetKeyToWellKnownOwnershipTracker = self._maid:Add(ObservableMapSet.new())

	self._assetOwnershipPromiseCache = {}

	self._maid:GiveTask(self._marketTracker.Purchased:Connect(function(idOrKey)
		self:SetOwnership(idOrKey, true)
	end))

	self._maid:GiveTask(self._attributesEnabled:Observe():Subscribe(function(isEnabled)
		if isEnabled then
			self._maid._wellKnown = self:_cacheWellKnownAssets()
		else
			self._maid._wellKnown = nil
		end
	end))

	return self
end

--[=[
	Sets the callback which will query ownership
	@param promiseOwnsAsset function
]=]
function PlayerAssetOwnershipTracker:SetQueryOwnershipCallback(promiseOwnsAsset)
	assert(type(promiseOwnsAsset) == "function" or promiseOwnsAsset == nil, "Bad promiseOwnsAsset")

	if self._ownershipCallback.Value == promiseOwnsAsset then
		return
	end

	self._assetOwnershipPromiseCache = {}
	self._ownershipCallback.Value = promiseOwnsAsset
end

function PlayerAssetOwnershipTracker:_promiseQueryIdOrKeyOwnershipCached(idOrKey)
	local promiseOwnershipCallback = self._ownershipCallback.Value
	if not promiseOwnershipCallback then
		return nil
	end

	local id = self._configPicker:ToAssetId(self._assetType, idOrKey)
	if not id then
		warn(string.format("[PlayerAssetOwnershipTracker._promiseQueryIdOrKeyOwnershipCached] - Nothing with key %q", tostring(idOrKey)))
		return Promise.resolved(false)
	end

	if self._assetOwnershipPromiseCache[id] ~= nil then
		if Promise.isPromise(self._assetOwnershipPromiseCache[id]) then
			return self._assetOwnershipPromiseCache[id]
		else
			return Promise.resolved(self._assetOwnershipPromiseCache[id])
		end
	end

	local promise = promiseOwnershipCallback(id)
	assert(Promise.isPromise(promise), "Expected promise from callack")

	promise = self._maid:GivePromise(promise)

	promise:Then(function(ownsItem)
		self._assetOwnershipPromiseCache[id] = ownsItem

		-- Cache this stuff
		if ownsItem then
			self:SetOwnership(idOrKey, true)
		end
	end)

	self._assetOwnershipPromiseCache[id] = promise

	return promise
end

function PlayerAssetOwnershipTracker:_observeQueryOwnershipIdOrKeyCachedBrio(idOrKey)
	return self._ownershipCallback:Observe():Pipe({
		RxBrioUtils.switchToBrio();
		RxBrioUtils.switchMapBrio(function()
			local promise = self:_promiseQueryIdOrKeyOwnershipCached(idOrKey)
			if promise then
				-- Do cached version
				return Rx.fromPromise(promise)
			else
				return Rx.of(false)
			end
		end);
	});
end

--[=[
	Sets whether attributes should be written for this asset type.
	@param attributesEnabled boolean
]=]
function PlayerAssetOwnershipTracker:SetWriteAttributesEnabled(attributesEnabled)
	assert(type(attributesEnabled) == "boolean", "Bad attributesEnabled")

	self._attributesEnabled.Value = attributesEnabled
end

--[=[
	Sets the players ownership of a the asset

	@param idOrKey number
	@param ownsAsset boolean
]=]
function PlayerAssetOwnershipTracker:SetOwnership(idOrKey, ownsAsset)
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "idOrKey")
	assert(type(ownsAsset) == "boolean", "Bad ownsAsset")

	local id = self._configPicker:ToAssetId(self._assetType, idOrKey)
	if not id then
		warn(string.format("[PlayerAssetOwnershipTracker.SetOwnership] - Nothing with key %q", tostring(idOrKey)))
		return
	end

	if self._ownedAssetIdSet:Contains(id) then
		return
	end

	self._ownedAssetIdSet:Add(id)

	if self._attributesEnabled.Value then
		local attributeNames = PlayerAssetOwnershipUtils.getAttributeNames(self._configPicker, self._assetType, idOrKey)
		for _, attributeName in pairs(attributeNames) do
			self._player:SetAttribute(attributeName, ownsAsset)
		end
	end

	-- Update trackers
	for _, wellOwnedAsset in pairs(self:_getWellKnownAssets(idOrKey)) do
		wellOwnedAsset:SetIsOwned(ownsAsset)
	end
end

--[=[
	Promises true if the user owns the asset and false otherwise

	@param idOrKey string | number
	@return Promise<boolean>
]=]
function PlayerAssetOwnershipTracker:PromiseOwnsAsset(idOrKey)
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "idOrKey")

	-- Check attributes
	if self._attributesEnabled.Value then
		local attributeNames = PlayerAssetOwnershipUtils.getAttributeNames(self._configPicker, self._assetType, idOrKey)
		for _, attributeName in pairs(attributeNames) do
			if self._player:GetAttribute(attributeName) then
				return Promise.resolved(true)
			end
		end
	end

local id = self._configPicker:ToAssetId(self._assetType, idOrKey)
	if id then
		if self._ownedAssetIdSet:Contains(id) then
			return Promise.resolved(true)
		end
	else
		warn(string.format("[PlayerAssetOwnershipTracker.PromiseOwnsAsset] - Nothing with key %q", tostring(idOrKey)))
	end

	-- Check actual callback querying Roblox
	local promise = self:_promiseQueryIdOrKeyOwnershipCached(idOrKey)
	if promise then
		return promise
	else
		-- Assume no ownership
		return Promise.resolved(false)
	end
end

--[=[
	Observes whether the player owns the asset or not
	@param idOrKey number | number
	@return Observable<boolean>
]=]
function PlayerAssetOwnershipTracker:ObserveOwnsAsset(idOrKey)
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return Rx.merge({
			-- Observe attributes
			PlayerAssetOwnershipUtils.observeAttributeNamesBrio(self._configPicker, self._assetType, idOrKey)
				:Pipe({
					RxBrioUtils.flatMapBrio(function(attributeName)
						return RxAttributeUtils.observeAttribute(self._player, attributeName)
					end);
				});

			-- Observe well known assets
			self:_observeWellKnownAsset(idOrKey):Pipe({
				RxBrioUtils.flatMapBrio(function(knownAsset)
					return knownAsset:ObserveIsOwned()
				end);
			});

			-- Observe our internal cache
			self._configPicker:ObserveToAssetIdBrio(self._assetType, idOrKey):Pipe({
				RxBrioUtils.flatMapBrio(function(id)
					return self._ownedAssetIdSet:ObserveContains(id)
				end);
			});

			-- Observe promise (in case we aren't a well known asset)
			self:_observeQueryOwnershipIdOrKeyCachedBrio(idOrKey);
		})
		:Pipe({
			RxBrioUtils.where(function(value)
				return value and true or false
			end);
			RxStateStackUtils.topOfStack(false);
			Rx.throttleDefer();
		})
end

function PlayerAssetOwnershipTracker:_getWellKnownAssets(idOrKey)
	if type(idOrKey) == "number" then
		return self._assetIdToWellKnownOwnershipTracker:GetListForKey(idOrKey)
	elseif type(idOrKey) == "string" then
		return self._assetKeyToWellKnownOwnershipTracker:GetListForKey(idOrKey)
	else
		error("[PlayerAssetOwnershipTracker._getWellKnownAssets] - Bad idOrKey")
	end
end

function PlayerAssetOwnershipTracker:_observeWellKnownAsset(idOrKey)
	if type(idOrKey) == "number" then
		return self._assetIdToWellKnownOwnershipTracker:ObserveItemsForKeyBrio(idOrKey)
	elseif type(idOrKey) == "string" then
		return self._assetKeyToWellKnownOwnershipTracker:ObserveItemsForKeyBrio(idOrKey)
	else
		error("[PlayerAssetOwnershipTracker._observeWellKnownAsset] - Bad idOrKey")
	end
end

function PlayerAssetOwnershipTracker:_cacheWellKnownAssets()
	local maid = Maid.new()

	maid:GiveTask(self._configPicker:ObserveActiveAssetOfTypeBrio(self._assetType):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local gameConfigMaid = brio:ToMaid()
		local gameConfigAsset = brio:GetValue()

		local wellKnownHandler = WellKnownAssetOwnershipHandler.new(self._player, gameConfigAsset)
		gameConfigMaid:GiveTask(wellKnownHandler)

		gameConfigMaid:GiveTask(Rx.combineLatest({
			ownershipCallback = self._ownershipCallback:Observe();
			assetId = gameConfigAsset:ObserveAssetId();
		}):Pipe({
			RxBrioUtils.switchToBrio();
			RxBrioUtils.switchMapBrio(function(state)
				if state.assetId then
					local promise = self:_promiseQueryIdOrKeyOwnershipCached(state.assetId)
					if promise then
						-- Do cached version
						return Rx.fromPromise(promise)
					else
						return Rx.of(false)
					end
				else
					return Rx.of(false)
				end
			end);
			RxStateStackUtils.topOfStack(false);
		}):Subscribe(function(owned)
			wellKnownHandler:SetIsOwned(owned)
		end))

		gameConfigMaid:GiveTask(self._assetIdToWellKnownOwnershipTracker:Push(gameConfigAsset:ObserveAssetId(), wellKnownHandler))
		gameConfigMaid:GiveTask(self._assetKeyToWellKnownOwnershipTracker:Push(gameConfigAsset:ObserveAssetKey(), wellKnownHandler))
	end))

	return maid
end


return PlayerAssetOwnershipTracker