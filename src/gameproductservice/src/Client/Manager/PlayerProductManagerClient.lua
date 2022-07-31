--[=[
	@client
	@class PlayerProductManagerClient
]=]

local require = require(script.Parent.loader).load(script)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PlayerProductManagerBase = require("PlayerProductManagerBase")
local PlayerProductManagerConstants = require("PlayerProductManagerConstants")
local GameConfigServiceClient = require("GameConfigServiceClient")
local Promise = require("Promise")

local PlayerProductManagerClient = setmetatable({}, PlayerProductManagerBase)
PlayerProductManagerClient.ClassName = "PlayerProductManagerClient"
PlayerProductManagerClient.__index = PlayerProductManagerClient

require("PromiseRemoteEventMixin"):Add(PlayerProductManagerClient, PlayerProductManagerConstants.REMOTE_EVENT_NAME)

function PlayerProductManagerClient.new(obj, serviceBag)
	local self = setmetatable(PlayerProductManagerBase.new(obj), PlayerProductManagerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigServiceClient = self._serviceBag:GetService(GameConfigServiceClient)


	if self._obj == Players.LocalPlayer then
		self._pendingPassPromises = {}

		self:PromiseRemoteEvent():Then(function(remoteEvent)
			self:_setupRemoteEventLocal(remoteEvent)
		end)

		self._maid:GiveTask(MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, isPurchased)
			if player == self._obj then
				self:_handlePassFinished(player, gamePassId, isPurchased)
			end
		end))
	end

	return self
end

function PlayerProductManagerClient:PromptGamePassPurchase(gamePassId)
	assert(type(gamePassId) == "number", "Bad gamePassId")
	assert(self._obj == Players.LocalPlayer, "Can only prompt local player")

	if self._pendingPassPromises[gamePassId] then
		return self._maid:GivePromise(self._pendingPassPromises[gamePassId])
	end

	MarketplaceService:PromptGamePassPurchase(self._obj, gamePassId)
	local promise = Promise.new()

	self._pendingPassPromises[gamePassId] = promise

	return self._maid:GivePromise(promise)
end

function PlayerProductManagerClient:_setupRemoteEventLocal(remoteEvent)
	-- Gear and other assets
	self._maid:GiveTask(MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
		if player == self._obj then
			remoteEvent:FireServer(PlayerProductManagerConstants.NOTIFY_PROMPT_FINISHED, assetId, isPurchased)
		end
	end))

	-- Products
	self._maid:GiveTask(MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, assetId, isPurchased)
		if self._obj.UserId == userId then
			remoteEvent:FireServer(PlayerProductManagerConstants.NOTIFY_PROMPT_FINISHED, assetId, isPurchased)
		end
	end))

	-- Gamepasses
	self._maid:GiveTask(MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, isPurchased)
		if player == self._obj then
			remoteEvent:FireServer(PlayerProductManagerConstants.NOTIFY_GAMEPASS_FINISHED, gamePassId, isPurchased)
		end
	end))
end

-- For overrides
function PlayerProductManagerClient:GetConfigPicker()
	return self._gameConfigServiceClient:GetConfigPicker()
end

function PlayerProductManagerClient:_handlePassFinished(player, gamePassId, isPurchased)
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


return PlayerProductManagerClient