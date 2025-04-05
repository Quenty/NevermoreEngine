--[=[
	@class AvatarEditorInventoryServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local AvatarEditorService = game:GetService("AvatarEditorService")

local AvatarEditorInventory = require("AvatarEditorInventory")
local AvatarEditorUtils = require("AvatarEditorUtils")
local EnumUtils = require("EnumUtils")
local Maid = require("Maid")
local MemorizeUtils = require("MemorizeUtils")
local Promise = require("Promise")
local ValueObject = require("ValueObject")
local PagesProxy = require("PagesProxy")
local _ServiceBag = require("ServiceBag")

local AvatarEditorInventoryServiceClient = {}
AvatarEditorInventoryServiceClient.ServiceName = "AvatarEditorInventoryServiceClient"

function AvatarEditorInventoryServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._isAccessAllowed = self._maid:Add(ValueObject.new(false, "boolean"))
	self._assetTypeToInventoryPromises = {}

	self._maid:GiveTask(AvatarEditorService.PromptAllowInventoryReadAccessCompleted:Connect(function(avatarPromptResult)
		if avatarPromptResult == Enum.AvatarPromptResult.Success then
			self._isAccessAllowed.Value = true
		end
	end))

	self._promiseInventoryPages = MemorizeUtils.memoize(function(avatarAssetTypes)
		return AvatarEditorUtils.promiseInventoryPages(avatarAssetTypes)
			:Then(function(catalogPages)
				-- Allow for replay
				return PagesProxy.new(catalogPages)
			end)
	end)
end

function AvatarEditorInventoryServiceClient:PromiseInventoryPages(avatarAssetTypes)
	return self:PromiseEnsureAccess()
		:Then(function()
			return self._promiseInventoryPages(avatarAssetTypes)
		end)
		:Then(function(pagesProxy)
			return pagesProxy:Clone()
		end)
end

function AvatarEditorInventoryServiceClient:PromiseInventoryForAvatarAssetType(avatarAssetType)
	assert(EnumUtils.isOfType(Enum.AvatarAssetType, avatarAssetType), "Bad avatarAssetType")

	if self._assetTypeToInventoryPromises[avatarAssetType] then
		return self._assetTypeToInventoryPromises[avatarAssetType]
	end

	local inventory = self._maid:Add(AvatarEditorInventory.new())

	self._assetTypeToInventoryPromises[avatarAssetType] = AvatarEditorUtils.promiseInventoryPages({
		avatarAssetType
	})
		:Then(function(inventoryPages)
			return inventory:PromiseProcessPages(inventoryPages)
		end)
		:Then(function()
			return inventory
		end)

	return self._assetTypeToInventoryPromises[avatarAssetType]
end

function AvatarEditorInventoryServiceClient:IsInventoryAccessAllowed()
	return self._isAccessAllowed.Value
end

function AvatarEditorInventoryServiceClient:ObserveIsInventoryAccessAllowed()
	return self._isAccessAllowed:Observe()
end

function AvatarEditorInventoryServiceClient:PromiseEnsureAccess()
	if self._isAccessAllowed.Value then
		return Promise.resolved()
	end

	if self._currentAccessPromise and self._currentAccessPromise:IsPending() then
		return self._currentAccessPromise
	end

	local promise = self._maid:GivePromise(AvatarEditorUtils.promptAllowInventoryReadAccess())

	promise:Then(function(avatarPromptResult)
		if avatarPromptResult == Enum.AvatarPromptResult.Success then
			self._isAccessAllowed.Value = true
		end
	end)

	self._currentAccessPromise = promise

	return self._currentAccessPromise
end

function AvatarEditorInventoryServiceClient:Destroy()
	self._maid:DoCleaning()
end

return AvatarEditorInventoryServiceClient