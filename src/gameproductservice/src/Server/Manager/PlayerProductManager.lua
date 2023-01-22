--[=[
	@class PlayerProductManager
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")

local PlayerProductManagerBase = require("PlayerProductManagerBase")
local PlayerProductManagerConstants = require("PlayerProductManagerConstants")
local Promise = require("Promise")
local GameConfigService = require("GameConfigService")

local PlayerProductManager = setmetatable({}, PlayerProductManagerBase)
PlayerProductManager.ClassName = "PlayerProductManager"
PlayerProductManager.__index = PlayerProductManager

function PlayerProductManager.new(obj, serviceBag)
	local self = setmetatable(PlayerProductManagerBase.new(obj), PlayerProductManager)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigService = self._serviceBag:GetService(GameConfigService)

	self._pendingProductPromises = {} -- { [number] = Promise<boolean> }
	self._pendingPassPromises = {} -- { [number] = Promise<boolean> }

	self._remoteEvent = Instance.new("RemoteEvent")
	self._remoteEvent.Name = PlayerProductManagerConstants.REMOTE_EVENT_NAME
	self._remoteEvent.Archivable = false
	self._remoteEvent.Parent = self._obj
	self._maid:GiveTask(self._remoteEvent)

	self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(...)
		self:_handleServerEvent(...)
	end))

	self._maid:GiveTask(function()
		self:_cancelAllPendingPrompts()
	end)

	self:InitOwnershipAttributes()

	return self
end

function PlayerProductManager:PromptGamePassPurchase(gamePassId)
	assert(type(gamePassId) == "number", "Bad gamePassId")

	if self._pendingPassPromises[gamePassId] then
		return self._maid:GivePromise(self._pendingPassPromises[gamePassId])
	end

	MarketplaceService:PromptGamePassPurchase(self._obj, gamePassId)
	local promise = Promise.new()

	self._pendingPassPromises[gamePassId] = promise

	return self._maid:GivePromise(promise)
end

function PlayerProductManager:PromisePromptPurchase(productId)
	assert(type(productId) == "number", "Bad productId")

	if self._pendingProductPromises[productId] then
		return self._maid:GivePromise(self._pendingProductPromises[productId])
	end

	MarketplaceService:PromptProductPurchase(self._obj, productId)
	local promise = Promise.new()

	self._pendingProductPromises[productId] = promise

	return self._maid:GivePromise(promise)
end

function PlayerProductManager:HandleProcessReceipt(player, receiptInfo)
	assert(self._obj == player, "Bad player")

	local pendingForAssetId = self._pendingProductPromises[receiptInfo.ProductId]
	if pendingForAssetId then
		self._pendingProductPromises[receiptInfo.ProductId] = nil
		pendingForAssetId:Resolve(true)

		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- For overrides
function PlayerProductManagerBase:GetConfigPicker()
	return self._gameConfigService:GetConfigPicker()
end

function PlayerProductManager:_handleServerEvent(player, request, ...)
	assert(self._obj == player, "Bad player")
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(request) == "string", "Bad request")

	if request == PlayerProductManagerConstants.NOTIFY_PROMPT_FINISHED then
		self:_handlePromptFinished(player, ...)
	elseif request == PlayerProductManagerConstants.NOTIFY_GAMEPASS_FINISHED then
		self:_handlePassFinished(player, ...)
	else
		error(("Bad request %q"):format(PlayerProductManager))
	end
end

function PlayerProductManager:_handlePassFinished(player, gamePassId, isPurchased)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(gamePassId) == "number", "Bad gamePassId")
	assert(type(isPurchased) == "boolean", "Bad isPurchased")

	local promise = self._pendingPassPromises[gamePassId]
	if promise then
		if isPurchased then
			-- TODO: verify this on the server here
			-- Can we break cache?
			self:SetPlayerOwnsPass(gamePassId, true)
		end

		self._pendingPassPromises[gamePassId] = nil
		promise:Resolve(isPurchased)
	end
end

function PlayerProductManager:_handlePromptFinished(player, productId, isPurchased)
	assert(typeof(player) == "Instance", "Bad player")
	assert(type(productId) == "number", "Bad productId")
	assert(type(isPurchased) == "boolean", "Bad isPurchased")

	local promise = self._pendingProductPromises[productId]
	if promise then
		-- Success handled by receipt processing
		if not isPurchased then
			self._pendingProductPromises[productId] = nil
			promise:Resolve(false)
		end
	end
end

function PlayerProductManager:_cancelAllPendingPrompts()
	while #self._pendingProductPromises > 0 do
		local pending = table.remove(self._pendingProductPromises, #self._pendingProductPromises)
		pending:Reject()
	end

	while #self._pendingProductPromises > 0 do
		local pending = table.remove(self._pendingProductPromises, #self._pendingProductPromises)
		pending:Reject()
	end
end

return PlayerProductManager