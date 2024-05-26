--[=[
	Handles product prompting state on the server

	@server
	@class PlayerProductManager
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local EnumUtils = require("EnumUtils")
local GameConfigAssetTypes = require("GameConfigAssetTypes")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local GameConfigService = require("GameConfigService")
local PlayerMarketeer = require("PlayerMarketeer")
local ReceiptProcessingService = require("ReceiptProcessingService")
local Remoting = require("Remoting")

local PlayerProductManager = setmetatable({}, BaseObject)
PlayerProductManager.ClassName = "PlayerProductManager"
PlayerProductManager.__index = PlayerProductManager

--[=[
	Managers players products and purchase state. Should be retrieved via binder.

	@param player Player
	@param serviceBag ServiceBag
	@return PlayerProductManager
]=]
function PlayerProductManager.new(player, serviceBag)
	local self = setmetatable(BaseObject.new(player), PlayerProductManager)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._gameConfigService = self._serviceBag:GetService(GameConfigService)
	self._receiptProcessingService = self._serviceBag:GetService(ReceiptProcessingService)

	self._marketeer = self._maid:Add(PlayerMarketeer.new(self._obj, self._gameConfigService:GetConfigPicker()))

	-- Expect configuration on receipt processing
	self._marketeer:GetAssetTrackerOrError(GameConfigAssetTypes.PRODUCT):SetReceiptProcessingExpected(true)

	self._remoting = self._maid:Add(Remoting.new(self._obj, "PlayerProductManager", Remoting.Realms.SERVER))
	self._remoting:DeclareEvent("NotifyReceiptProcessed")

	self._maid:GiveTask(self._remoting.NotifyPromptFinished:Connect(function(...)
		self:_handlePromptFinished(...)
	end))

	self._maid:GiveTask(self._receiptProcessingService:ObserveReceiptProcessedForPlayer(self._obj):Subscribe(function(receiptInfo, result)
		self:_handleProcessReceipt(receiptInfo, result)
	end))

	-- Initialize attributes
	self._marketeer:GetOwnershipTrackerOrError(GameConfigAssetTypes.PASS):SetWriteAttributesEnabled(true)

	return self
end

function PlayerProductManager:GetMarketeer()
	return self._marketeer
end

--[=[
	Gets the current player
	@return Player
]=]
function PlayerProductManager:GetPlayer()
	return self._obj
end

function PlayerProductManager:_handlePromptFinished(player, assetType, assetId, isPurchased)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetId) == "number", "Bad assetId")
	assert(type(isPurchased) == "boolean", "Bad isPurchased")

	local assetTracker = self._marketeer:GetAssetTrackerOrError(assetType)
	assetTracker:HandlePurchaseEvent(assetId, isPurchased)
end

function PlayerProductManager:_handleProcessReceipt(receiptInfo, productPurchaseDecision)
	assert(type(receiptInfo) == "table", "Bad receiptInfo")
	assert(EnumUtils.isOfType(Enum.ProductPurchaseDecision, productPurchaseDecision), "Bad decision")

	local assetTracker = self._marketeer:GetAssetTrackerOrError(GameConfigAssetTypes.PRODUCT)

	-- Notify the player
	self._remoting.NotifyReceiptProcessed:FireClient(self._obj, receiptInfo)

	assetTracker:HandleProcessReceipt(self._obj, receiptInfo)
end

return PlayerProductManager