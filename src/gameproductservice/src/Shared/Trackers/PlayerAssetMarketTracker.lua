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

	self._pendingPromises = {} -- { [number] = Promise<boolean> }
	self._purchasedThisSession = {} -- [number] = true
	self._receiptProcessingExpected = false

	self._promptsOpen = Instance.new("IntValue")
	self._promptsOpen.Value = 0
	self._maid:GiveTask(self._promptsOpen)

	self.Purchased = Signal.new() -- :Fire(id)
	self._maid:GiveTask(self.Purchased)

	self.PromptFinished = Signal.new() -- :Fire(id, isPurchased)
	self._maid:GiveTask(self.PromptFinished)

	self.ShowPromptRequested = Signal.new() -- :Fire(id)
	self._maid:GiveTask(self.ShowPromptRequested)

	self._maid:GiveTask(function()
		while #self._purchasedThisSession > 0 do
			local pending = table.remove(self._purchasedThisSession, #self._purchasedThisSession)
			pending:Reject()
		end
	end)

	return self
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
		return Promise.rejected(("No %s with key %q"):format(self._assetType, tostring(idOrKey)))
	end

	if self._pendingPromises[id] then
		return self._maid:GivePromise(self._pendingPromises[id])
	end

	local ownershipPromise
	if self._ownershipTracker then
		ownershipPromise = self._ownershipTracker:PromiseOwnsAsset(id)
	else
		ownershipPromise = Promise.resolved(false)
	end

	return ownershipPromise:Then(function(ownsAsset)
		if ownsAsset then
			return true
		end

		local promise = Promise.new()
		self._pendingPromises[id] = promise

		self._promptsOpen.Value = self._promptsOpen.Value + 1

		promise:Finally(function()
			self._promptsOpen.Value = self._promptsOpen.Value - 1
		end)

		self.ShowPromptRequested:Fire(id)

		return self._maid:GivePromise(promise)
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
	return self._promptsOpen.Value > 0
end

--[=[
	Handles a purchasing event resolving any promises as needed

	@param id number
	@param isPurchased boolean
]=]
function PlayerAssetMarketTracker:HandlePurchaseEvent(id, isPurchased)
	assert(type(id) == "number", "Bad id")
	assert(type(isPurchased) == "boolean", "Bad isPurchased")

	self:_handlePurchaseEvent(id, isPurchased, false)
end

function PlayerAssetMarketTracker:_handlePurchaseEvent(id, isPurchased, isFromReceipt)
	assert(type(id) == "number", "Bad id")
	assert(type(isPurchased) == "boolean", "Bad isPurchased")

	local promise = self._pendingPromises[id]

	-- Zero out promise resolution in receipt processing scenario (safety)
	if self._receiptProcessingExpected then
		if isPurchased and not isFromReceipt then
			promise = nil
		end
	end

	if promise then
		self._pendingPromises[id] = nil
	end

	if isPurchased then
		self._purchasedThisSession[id] = true

		if self._receiptProcessingExpected then
			if isFromReceipt then
				self.Purchased:Fire(id)
			end
		else
			self.Purchased:Fire(id)
		end
	end

	if not isFromReceipt then
		self.PromptFinished:Fire(id, isPurchased)
	end

	if promise then
		task.spawn(function()
			promise:Resolve(isPurchased)
		end)
	end
end

--[=[
	Sets if this tracker is handling purchase receipts as a more authenticated mechanism

	@param receiptProcessingExpected boolean
]=]
function PlayerAssetMarketTracker:SetReceiptProcessingExpected(receiptProcessingExpected)
	assert(type(receiptProcessingExpected) == "boolean", "Bad receiptProcessingExpected")

	self._receiptProcessingExpected = receiptProcessingExpected
end

--[=[
	Gets if this tracker is handling purchase receipts as a more authenticated mechanism

	@return boolean
]=]
function PlayerAssetMarketTracker:GetReceiptProcessingExpected()
	return self._receiptProcessingExpected
end

--[=[
	Handles the receipt processing

	@param player Player
	@param receiptInfo ReceiptInfo
	@return ProductPurchaseDecision
]=]
function PlayerAssetMarketTracker:HandleProcessReceipt(player, receiptInfo)
	assert(typeof(player) == "Instance", "Bad player")
	assert(self._receiptProcessingExpected, "No receiptProcessingExpected")

	self:_handlePurchaseEvent(receiptInfo.ProductId, true, true)

	-- Always grant...
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return PlayerAssetMarketTracker