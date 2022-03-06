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

local PlayerProductManagerClient = setmetatable({}, PlayerProductManagerBase)
PlayerProductManagerClient.ClassName = "PlayerProductManagerClient"
PlayerProductManagerClient.__index = PlayerProductManagerClient

require("PromiseRemoteEventMixin"):Add(PlayerProductManagerClient, PlayerProductManagerConstants.REMOTE_EVENT_NAME)

function PlayerProductManagerClient.new(obj, serviceBag)
	local self = setmetatable(PlayerProductManagerBase.new(obj), PlayerProductManagerClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigServiceClient = self._serviceBag:GetService(GameConfigServiceClient)

	if self._obj == Players.LocalPlayer then
		self:PromiseRemoteEvent():Then(function(remoteEvent)
			self:_setupRemoteEventLocal(remoteEvent)
		end)
	end

	return self
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

return PlayerProductManagerClient