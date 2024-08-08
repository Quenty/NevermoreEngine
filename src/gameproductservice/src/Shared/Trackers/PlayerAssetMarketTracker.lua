--[=[
	Tracks a single asset type for pending purchase prompts.

	@class PlayerAssetMarketTracker
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local Promise = require("Promise")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local PlayerAssetMarketTracker = setmetatable({}, BaseObject)
PlayerAssetMarketTracker.ClassName = "PlayerAssetMarketTracker"
PlayerAssetMarketTracker.__index = PlayerAssetMarketTracker

--[=[
	@param assetType GameConfigAssetTypes
	@param convertIds function
	@param observeIdsBrio function
	@return PlayerAssetMarketTracker
]=]
function PlayerAssetMarketTracker.new(assetType, convertIds, observeIdsBrio)
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")

	local self = setmetatable(BaseObject.new(), PlayerAssetMarketTracker)

	self._assetType = assert(assetType, "No assetType")
	self._convertIds = assert(convertIds, "No convertIds")
	self._observeIdsBrio = assert(observeIdsBrio, "No observeIdsBrio")

	self._pendingPurchasePromises = {} -- { [number] = Promise<boolean> }
	self._pendingPromptOpenPromises = {} -- { [number] = Promise<boolean> }

	self._purchasedThisSession = {} -- [number] = true

	self._promptsOpenCount = self._maid:Add(ValueObject.new(0, "number"))

	self.Purchased = self._maid:Add(Signal.new()) -- :Fire(id)
	self.PromptClosed = self._maid:Add(Signal.new()) -- :Fire(id, isPurchased)
	self.ShowPromptRequested = self._maid:Add(Signal.new()) -- :Fire(id)

	self._maid:GiveTask(self.Purchased:Connect(function(id)
		self._purchasedThisSession[id] = true
	end))

	self._maid:GiveTask(self._promptsOpenCount:Observe():Subscribe(function(promptsOpen)
		if promptsOpen <= 0 then
			local promise = self._promiseNoPromptOpen
			self._promiseNoPromptOpen = nil
			if promise then
				promise:Resolve()
			end
		end
	end))

	self._maid:GiveTask(function()
		while #self._pendingPurchasePromises > 0 do
			local pending = table.remove(self._pendingPurchasePromises, #self._pendingPurchasePromises)
			pending:Reject()
		end

		while #self._pendingPromptOpenPromises > 0 do
			local pending = table.remove(self._pendingPromptOpenPromises, #self._pendingPromptOpenPromises)
			pending:Reject()
		end
	end)

	return self
end

function PlayerAssetMarketTracker:ObservePromptOpenCount()
	return self._promptsOpenCount:Observe()
end

--[=[
	Observes an asset purchased

	@param idOrKey string | number
	@return Observable<()>
]=]
function PlayerAssetMarketTracker:ObserveAssetPurchased(idOrKey)
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	return Observable.new(function(sub)
		local topMaid = Maid.new()
		local knownIds = {}

		topMaid:GiveTask(self._observeIdsBrio(idOrKey):Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid = brio:ToMaid()
			local id = brio:GetValue()

			knownIds[id] = (knownIds[id] or 0) + 1

			maid:GiveTask(function()
				knownIds[id] = (knownIds[id] or 0) - 1
				if knownIds[id] <= 0 then
					knownIds[id] = nil
				end
			end)
		end))

		topMaid:GiveTask(self.Purchased:Connect(function(purchasedId)
			if knownIds[purchasedId] then
				sub:Fire()
			end
		end))

		return topMaid
	end)
end

function PlayerAssetMarketTracker:GetOwnershipTracker()
	return self._ownershipTracker
end

--[=[
	Prompts the player to purchase a the asset and returns a tracking promise which
	will resolve with the purchase state

	@param idOrKey number | string
	@return Promise<boolean>
]=]
function PlayerAssetMarketTracker:PromisePromptPurchase(idOrKey)
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "Bad idOrKey")

	local id = self._convertIds(idOrKey)
	if not id then
		return Promise.rejected(string.format("[PlayerAssetMarketTracker.PromisePromptPurchase] - No %s with key %q",
			self._assetType,
			tostring(idOrKey)))
	end

	return Promise.resolved()
		:Then(function()
			if self._ownershipTracker then
				return self._maid:GivePromise(self._ownershipTracker:PromiseOwnsAsset(id))
			else
				return false
			end
		end)
		:Then(function(ownsAsset)
			if ownsAsset then
				return true
			end

			-- We reject here because there's no safe way to queue this
			if self._promptsOpenCount.Value > 0 then
				return Promise.rejected(string.format("[PlayerAssetMarketTracker] - Either already prompting user, or prompting is on cooldown. Will not prompt for %s", idOrKey))
			end

			-- We reject here because there's no safe way to queue this
			if self._pendingPurchasePromises[id] then
				return Promise.rejected(string.format("[PlayerAssetMarketTracker] - Already prompting user. Will not prompt for %s", idOrKey))
			end

			if self._pendingPromptOpenPromises[id] then
				warn("[PlayerAssetMarketTracker] - Failure. Prompts open should be tracking this.")

				return Promise.rejected(string.format("[PlayerAssetMarketTracker] - Already prompting user. Will not prompt for %s", idOrKey))
			end

			do
				local promptOpenPromise = Promise.new()
				self._pendingPromptOpenPromises[id] = promptOpenPromise

				self._promptsOpenCount.Value = self._promptsOpenCount.Value + 1
				promptOpenPromise:Finally(function()
					if self._pendingPromptOpenPromises[id] == promptOpenPromise then
						self._pendingPromptOpenPromises[id] = nil
					end
					self._promptsOpenCount.Value = self._promptsOpenCount.Value - 1
				end)
			end

			-- Make sure to do promise here so we can't double-open prompts
			local purchasePromise = Promise.new()
			self._pendingPurchasePromises[id] = purchasePromise

			purchasePromise:Finally(function()
				if self._pendingPurchasePromises[id] == purchasePromise then
					self._pendingPurchasePromises[id] = nil
				end
			end)

			self.ShowPromptRequested:Fire(id)

			return self._maid:GivePromise(purchasePromise)
		end)
end

--[=[
	Sets the ownership tracker for this asset tracker

	@param ownershipTracker PlayerAssetOwnershipTracker
]=]
function PlayerAssetMarketTracker:SetOwnershipTracker(ownershipTracker)
	assert(type(ownershipTracker) == "table" or ownershipTracker == nil, "Bad ownershipTracker")

	self._ownershipTracker = ownershipTracker
end

function PlayerAssetMarketTracker:GetAssetType()
	return self._assetType
end

--[=[
	Returns true if item has been purchased this session

	@param idOrKey string | number
	@return boolean
]=]
function PlayerAssetMarketTracker:HasPurchasedThisSession(idOrKey)
	assert(type(idOrKey) == "number" or type(idOrKey) == "string", "idOrKey")

	local id = self._convertIds(idOrKey)
	if not id then
		warn(("[PlayerAssetMarketTracker] - No %s with key %q"):format(self._assetType, tostring(idOrKey)))
		return false
	end

	if self._purchasedThisSession[id] then
		return true
	end

	return false
end

--[=[
	Returns true if a prompt is open for the asset

	@return boolean
]=]
function PlayerAssetMarketTracker:IsPromptOpen()
	return self._promptsOpenCount.Value > 0
end

--[=[
	Handles a purchasing event resolving any promises as needed

	@param id number
	@param isPurchased boolean
]=]
function PlayerAssetMarketTracker:HandlePurchaseEvent(id, isPurchased)
	assert(type(id) == "number", "Bad id")
	assert(type(isPurchased) == "boolean", "Bad isPurchased")

	local purchasePromise = self._pendingPurchasePromises[id] or Promise.new()

	if isPurchased then
		self.Purchased:Fire(id)
	end

	purchasePromise:Resolve(isPurchased)
end

function PlayerAssetMarketTracker:HandlePromptClosedEvent(id)
	assert(type(id) == "number", "Bad id")

	local promptOpenPromise = self._pendingPromptOpenPromises[id] or Promise.new()
	promptOpenPromise:Resolve()
end

return PlayerAssetMarketTracker