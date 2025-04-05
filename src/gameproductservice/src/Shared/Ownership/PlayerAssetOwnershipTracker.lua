--[=[
	This tracking is relatively complicated because we want to track both
	ownership from attributes (can be customized locally), as well as async
	cloud services.

	@class PlayerAssetOwnershipTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local ObservableSet = require("ObservableSet")
local Promise = require("Promise")
local ValueObject = require("ValueObject")
local Observable = require("Observable")
local Maid = require("Maid")

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
	self._ownedAssetIdSet = self._maid:Add(ObservableSet.new())

	self._assetOwnershipPromiseCache = {}

	self._maid:GiveTask(self._marketTracker.Purchased:Connect(function(idOrKey)
		self:SetOwnership(idOrKey, true)
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

function PlayerAssetOwnershipTracker:_promiseQueryAssetId(assetId: number)
	assert(type(assetId) == "number", "Bad assetId")

	local promiseOwnershipCallback = self._ownershipCallback.Value
	if not promiseOwnershipCallback then
		return Promise.rejected(string.format("[PlayerAssetOwnershipTracker] - Cannot query ownership for assetType %q - No ownership callback set", tostring(self._assetType)))
	end

	if self._assetOwnershipPromiseCache[assetId] ~= nil then
		if Promise.isPromise(self._assetOwnershipPromiseCache[assetId]) then
			return self._assetOwnershipPromiseCache[assetId]
		else
			return Promise.resolved(self._assetOwnershipPromiseCache[assetId])
		end
	end

	local promise = promiseOwnershipCallback(assetId)
	assert(Promise.isPromise(promise), "Expected promise from callack")

	promise = self._maid:GivePromise(promise)

	promise:Then(function(ownsItem)
		self._assetOwnershipPromiseCache[assetId] = ownsItem

		-- Cache this stuff
		if ownsItem then
			self:SetOwnership(assetId, true)
		end
	end)

	self._assetOwnershipPromiseCache[assetId] = promise

	return promise
end

--[=[
	Sets the players ownership of a the asset

	@param idOrKey number
	@param ownsAsset boolean
]=]
function PlayerAssetOwnershipTracker:SetOwnership(idOrKey, ownsAsset)
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "idOrKey")
	assert(type(ownsAsset) == "boolean", "Bad ownsAsset")

	local assetId = self._configPicker:ToAssetId(self._assetType, idOrKey)
	if not assetId then
		warn(string.format("[PlayerAssetOwnershipTracker.SetOwnership] - Nothing with key %q", tostring(idOrKey)))
		return
	end

	if self._ownedAssetIdSet:Contains(assetId) then
		return
	end

	self._ownedAssetIdSet:Add(assetId)
end

--[=[
	Promises true if the user owns the asset and false otherwise

	@param idOrKey string | number
	@return Promise<boolean>
]=]
function PlayerAssetOwnershipTracker:PromiseOwnsAsset(idOrKey)
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "idOrKey")

	local assetId = self._configPicker:ToAssetId(self._assetType, idOrKey)
	if assetId then
		if self._ownedAssetIdSet:Contains(assetId) then
			return Promise.resolved(true)
		end
	else
		return Promise.rejected(string.format("[PlayerAssetOwnershipTracker.PromiseOwnsAsset] - Nothing with key %q", tostring(idOrKey)))
	end

	-- Check actual callback querying Roblox
	local promise = self:_promiseQueryAssetId(assetId)
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

	-- TODO: Get rid of several concepts here, including well known assets, attributes, and more

	if type(idOrKey) == "string" then
		return Observable.new(function(sub)
			local topMaid = Maid.new()

			topMaid:GiveTask(self._configPicker:ObserveToAssetIdBrio(self._assetType, idOrKey):Subscribe(function(brio)
				if brio:IsDead() then
					return
				end

				-- Only fire once we find the asset
				local maid, assetId = brio:ToMaidAndValue()
				maid:GivePromise(self:_promiseQueryAssetId(assetId))
					:Then(function()
						maid:GiveTask(self._ownedAssetIdSet:ObserveContains(assetId):Subscribe(function(value)
							sub:Fire(value)
						end))
					end)
			end))

			return topMaid
		end)


	elseif type(idOrKey) == "number" then
		return Observable.new(function(sub)
			local maid = Maid.new()

			maid:GivePromise(self:_promiseQueryAssetId(idOrKey))
				:Then(function()
					-- Only fire once we find ownership status

					maid:GiveTask(self._ownedAssetIdSet:ObserveContains(idOrKey):Subscribe(function(value)
						sub:Fire(value)
					end))
				end)

			return maid
		end)
	else
		error("Bad idOrKey")
	end

end


return PlayerAssetOwnershipTracker