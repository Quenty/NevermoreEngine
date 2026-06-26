--!strict
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
local PagesProxy = require("PagesProxy")
local Promise = require("Promise")
local ServiceBag = require("ServiceBag")
local ValueObject = require("ValueObject")

local AvatarEditorInventoryServiceClient = {}
AvatarEditorInventoryServiceClient.ServiceName = "AvatarEditorInventoryServiceClient"

export type AvatarEditorInventoryServiceClient = typeof(setmetatable(
	{} :: {
		_maid: Maid.Maid,
		_serviceBag: ServiceBag.ServiceBag,
		_isAccessAllowed: ValueObject.ValueObject<boolean>,
		_assetTypeToInventoryPromises: { [Enum.AvatarAssetType]: any },
		_promiseInventoryPages: any,
		_currentAccessPromise: any,
	},
	{} :: typeof({ __index = AvatarEditorInventoryServiceClient })
))

function AvatarEditorInventoryServiceClient.Init(
	self: AvatarEditorInventoryServiceClient,
	serviceBag: ServiceBag.ServiceBag
): ()
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

	self._promiseInventoryPages = MemorizeUtils.memoize(function(avatarAssetTypes: { Enum.AvatarAssetType })
		return (AvatarEditorUtils.promiseInventoryPages(avatarAssetTypes):Then(function(catalogPages)
			-- Allow for replay
			return PagesProxy.new(catalogPages)
		end)) :: any
	end)
end

function AvatarEditorInventoryServiceClient.PromiseInventoryPages(
	self: AvatarEditorInventoryServiceClient,
	avatarAssetTypes: Enum.AvatarAssetType
): Promise.Promise<PagesProxy.PagesProxy>
	return (self:PromiseEnsureAccess()
		:Then(function()
			return self._promiseInventoryPages(avatarAssetTypes)
		end)
		:Then(function(pagesProxy)
			return pagesProxy:Clone()
		end)) :: any
end

function AvatarEditorInventoryServiceClient.PromiseInventoryForAvatarAssetType(
	self: AvatarEditorInventoryServiceClient,
	avatarAssetType: Enum.AvatarAssetType
): Promise.Promise<AvatarEditorInventory.AvatarEditorInventory>
	assert(EnumUtils.isOfType(Enum.AvatarAssetType, avatarAssetType), "Bad avatarAssetType")

	if self._assetTypeToInventoryPromises[avatarAssetType] then
		return self._assetTypeToInventoryPromises[avatarAssetType]
	end

	local inventory = self._maid:Add(AvatarEditorInventory.new())

	self._assetTypeToInventoryPromises[avatarAssetType] = (AvatarEditorUtils.promiseInventoryPages({
		avatarAssetType,
	})
		:Then(function(inventoryPages)
			return inventory:PromiseProcessPages(inventoryPages)
		end)
		:Then(function()
			return inventory
		end)) :: any

	return self._assetTypeToInventoryPromises[avatarAssetType]
end

function AvatarEditorInventoryServiceClient.IsInventoryAccessAllowed(self: AvatarEditorInventoryServiceClient): boolean
	return self._isAccessAllowed.Value
end

function AvatarEditorInventoryServiceClient.ObserveIsInventoryAccessAllowed(
	self: AvatarEditorInventoryServiceClient
): any
	return self._isAccessAllowed:Observe()
end

function AvatarEditorInventoryServiceClient.PromiseEnsureAccess(
	self: AvatarEditorInventoryServiceClient
): Promise.Promise<()>
	if self._isAccessAllowed.Value then
		return (Promise :: any).resolved()
	end

	if self._currentAccessPromise and self._currentAccessPromise:IsPending() then
		return self._currentAccessPromise
	end

	local promise: any = self._maid:GivePromise(AvatarEditorUtils.promptAllowInventoryReadAccess())

	promise:Then(function(avatarPromptResult)
		if avatarPromptResult == Enum.AvatarPromptResult.Success then
			self._isAccessAllowed.Value = true
		end
	end)

	self._currentAccessPromise = promise

	return promise
end

function AvatarEditorInventoryServiceClient.Destroy(self: AvatarEditorInventoryServiceClient): ()
	self._maid:DoCleaning()
end

return AvatarEditorInventoryServiceClient
