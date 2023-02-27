--[=[
	Handles product prompting state on the server

	@server
	@class PlayerProductManager
]=]

local require = require(script.Parent.loader).load(script)

local GameConfigService = require("GameConfigService")
local BaseObject = require("BaseObject")
local PlayerProductManagerConstants = require("PlayerProductManagerConstants")
local GameConfigAssetTypeUtils = require("GameConfigAssetTypeUtils")
local PlayerMarketeer = require("PlayerMarketeer")
local GameConfigAssetTypes = require("GameConfigAssetTypes")

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

	self._marketeer = PlayerMarketeer.new(self._obj, self._gameConfigService:GetConfigPicker())
	self._maid:GiveTask(self._marketeer)

	-- Expect configuration on receipt processing
	self._marketeer:GetAssetTrackerOrError(GameConfigAssetTypes.PRODUCT):SetReceiptProcessingExpected(true)

	self._remoteEvent = Instance.new("RemoteEvent")
	self._remoteEvent.Name = PlayerProductManagerConstants.REMOTE_EVENT_NAME
	self._remoteEvent.Archivable = false
	self._remoteEvent.Parent = self._obj
	self._maid:GiveTask(self._remoteEvent)

	self._maid:GiveTask(self._remoteEvent.OnServerEvent:Connect(function(...)
		self:_handleServerEvent(...)
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

function PlayerProductManager:_handleServerEvent(player, request, ...)
	assert(self._obj == player, "Bad player")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(type(request) == "string", "Bad request")

	if request == PlayerProductManagerConstants.NOTIFY_PROMPT_FINISHED then
		self:_handlePromptFinished(player, ...)
	else
		error(("Bad request %q"):format(PlayerProductManager))
	end
end

function PlayerProductManager:_handlePromptFinished(player, assetType, assetId, isPurchased)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")
	assert(GameConfigAssetTypeUtils.isAssetType(assetType), "Bad assetType")
	assert(type(assetId) == "number", "Bad assetId")
	assert(type(isPurchased) == "boolean", "Bad isPurchased")

	local assetTracker = self._marketeer:GetAssetTrackerOrError(assetType)
	assetTracker:HandlePurchaseEvent(assetId, isPurchased)
end

--[=[
	Handles the receipt processing. Not expected to be called immediately

	@param player number
	@param receiptInfo table
	@return ProductPurchaseDecision
]=]
function PlayerProductManager:HandleProcessReceipt(player, receiptInfo)
	assert(self._obj == player, "Bad player")

	local assetTracker = self._marketeer:GetAssetTrackerOrError(GameConfigAssetTypes.PRODUCT)
	return assetTracker:HandleProcessReceipt(player, receiptInfo)
end

return PlayerProductManager