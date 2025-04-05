--!strict
--[=[
	Provides utilities to query the AvatarEditorService with a promise wrapper.

	@class AvatarEditorUtils
]=]

local require = require(script.Parent.loader).load(script)

local AvatarEditorService = game:GetService("AvatarEditorService")
local RunService = game:GetService("RunService")

local EnumUtils = require("EnumUtils")
local Maid = require("Maid")
local Promise = require("Promise")

local AvatarEditorUtils = {}

--[=[
	Holds item details for a bundle
	https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService#GetItemDetails

	@interface AvatarItemBundledItemDetails
	.Owned boolean
	.Id number
	.Name string
	.Type string
	@within AvatarEditorUtils
]=]
export type AvatarItemBundledItemDetails = {
	Owned: boolean,
	Id: number,
	Name: string,
	Type: string,
}

--[=[
	Holds premium pricing detail
	https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService#GetItemDetails
	@interface PremiumPricingItemDetails
	.PremiumDiscountPercentage number
	.PremiumPriceInRobux number
	@within AvatarEditorUtils
]=]
export type PremiumPricingItemDetails = {
	PremiumDiscountPercentage: number,
	PremiumPriceInRobux: number,
}

--[=[
	A table with a variety of information about avatar items and details.
	https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService#GetItemDetails

	@interface AvatarItemDetails
	.IsForRent boolean
	.ExpectedSellerId number
	.Owned boolean
	.IsPurchasable boolean
	.Id number
	.ItemType "Asset" | "Bundle" | string
	.AssetType "Image" | string
	.BundleType "BodyParts" | string
	.Name string
	.Description string
	.ProductId number
	.Genres { string }
	.BundledItems { AvatarItemBundledItemDetails }
	.ItemStatus { string }
	.ItemRestrictions { "ThirteenPlus" }
	.CreatorType "User" | string
	.CreatorTargetId number
	.CreatorName string
	.Price number
	.PremiumPricing PremiumPricingItemDetails
	.LowestPrice number
	.PriceStatus string
	.UnitsAvailableForConsumption number
	.PurchaseCount number
	.FavoriteCount number
	@within AvatarEditorUtils
]=]
export type AvatarItemDetails = {
	IsForRent: boolean,
	ExpectedSellerId: number,
	Owned: boolean,
	IsPurchasable: boolean,
	Id: number,
	ItemType: "Asset" | "Bundle" | string,
	AssetType: "Image" | string,
	BundleType: "BodyParts" | string,
	Name: string,
	Description: string,
	ProductId: number,
	Genres: { string },
	BundledItems: { AvatarItemBundledItemDetails },
	ItemStatus: { string },
	ItemRestrictions: "ThirteenPlus",
	CreatorType: "User" | string,
	CreatorTargetId: number,
	CreatorName: string,
	Price: number,
	PremiumPricing: PremiumPricingItemDetails,
	LowestPrice: number,
	PriceStatus: string,
	UnitsAvailableForConsumption: number,
	PurchaseCount: number,
	FavoriteCount: number,
}

--[=[
	This function returns the item details for the given item.
	It accepts two parameters - the first indicating the ID of the item being retrieved
	and the second indicating its [Enum.ItemType].

	@param itemType AvatarItemType
	@param itemId number
	@return Promise<AvatarItemDetails>
]=]
function AvatarEditorUtils.promiseItemDetails(
	itemId: number,
	itemType: Enum.AvatarItemType
): Promise.Promise<AvatarItemDetails>
	assert(type(itemId) == "number", "Bad itemId")
	assert(EnumUtils.isOfType(Enum.AvatarItemType, itemType), "Bad itemType")

	return Promise.spawn(function(resolve, reject)
		local itemDetails: AvatarItemDetails
		local ok, err = pcall(function()
			itemDetails = AvatarEditorService:GetItemDetails(itemId, itemType)
		end)

		if not ok then
			return reject(err or "[AvatarEditorUtils.promiseItemDetails] - Failed to GetItemDetails")
		end

		if type(itemDetails) ~= "table" then
			return reject("[AvatarEditorUtils.promiseItemDetails] - Bad itemDetails result")
		end

		return resolve(itemDetails)
	end)
end

--[=[
	Gets the item details for a list of items at once. More efficient than [AvatarEditorService.GetItemDetails]
	if you need to get all the item details of a list.

	@param itemIds { number }
	@param itemType AvatarItemType
	@return Promise<{ { AvatarItemDetails } >
]=]
function AvatarEditorUtils.promiseBatchItemDetails(
	itemIds: { number },
	itemType: Enum.AvatarItemType
): Promise.Promise<{ AvatarItemDetails }>
	assert(type(itemIds) == "table", "Bad itemIds")
	assert(EnumUtils.isOfType(Enum.AvatarItemType, itemType), "Bad itemType")

	return Promise.spawn(function(resolve, reject)
		local batchItemDetailsList: { AvatarItemDetails }
		local ok, err = pcall(function()
			batchItemDetailsList = AvatarEditorService:GetBatchItemDetails(itemIds, itemType)
		end)

		if not ok then
			return reject(err or "[AvatarEditorUtils.promiseBatchItemDetails] - Failed to GetBatchItemDetails")
		end

		if type(batchItemDetailsList) ~= "table" then
			return reject("[AvatarEditorUtils.promiseBatchItemDetails] - Got bad batchItemDetailsList result")
		end

		return resolve(batchItemDetailsList)
	end)
end

--[=[
	Returns a new HumanoidDescription with the Shirt and Pants properties updated if necessary.
	Returns nil if default clothing was not needed.

	Default clothing is necessary if the HumanoidDescription does not currently have Shirt and
	Pants equipped and the body colors are too similar.

	@param humanoidDescription HumanoidDescription
	@return Promise<HumanoidDescription?>
]=]
function AvatarEditorUtils.promiseCheckApplyDefaultClothing(humanoidDescription: HumanoidDescription): Promise.Promise<HumanoidDescription?>
	assert(
		typeof(humanoidDescription) == "Instance" and humanoidDescription:IsA("HumanoidDescription"),
		"Bad humanoidDescription"
	)

	return Promise.spawn(function(resolve, reject)
		local newDescriptionOrNil
		local ok, err = pcall(function()
			newDescriptionOrNil = AvatarEditorService:CheckApplyDefaultClothing(humanoidDescription)
		end)

		if not ok then
			return reject(
				err or "[AvatarEditorUtils.promiseCheckApplyDefaultClothing] - Failed to CheckApplyDefaultClothing"
			)
		end

		if newDescriptionOrNil == nil then
			return resolve(newDescriptionOrNil)
		end

		if not (typeof(newDescriptionOrNil) == "Instance" and newDescriptionOrNil:IsA("HumanoidDescription")) then
			return reject("[AvatarEditorUtils.promiseCheckApplyDefaultClothing] - Got bad humanoidDescription result")
		end

		return resolve(newDescriptionOrNil)
	end)
end

--[=[
	Probably makes the humanoid description conform to avatar rules.

	@param humanoidDescription HumanoidDescription
	@return Promise<HumanoidDescription>
]=]
function AvatarEditorUtils.promiseConformToAvatarRules(humanoidDescription: HumanoidDescription)
	assert(
		typeof(humanoidDescription) == "Instance" and humanoidDescription:IsA("HumanoidDescription"),
		"Bad humanoidDescription"
	)

	return Promise.spawn(function(resolve, reject)
		local newDescription
		local ok, err = pcall(function()
			newDescription = AvatarEditorService:ConformToAvatarRules(humanoidDescription)
		end)

		if not ok then
			return reject(
				err or "[AvatarEditorUtils.promiseConformToAvatarRules] - Failed to CheckApplyDefaultClothing"
			)
		end

		if not (typeof(newDescription) == "Instance" and newDescription:IsA("HumanoidDescription")) then
			return reject("[AvatarEditorUtils.promiseConformToAvatarRules] - Got bad humanoidDescription result")
		end

		return resolve(newDescription)
	end)
end

--[=[
	https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService#GetAvatarRules

	@interface AvatarRulesWearableAssetType
	.MaxNumber number
	.Id number
	.Name string
	@within AvatarEditorUtils
]=]
export type AvatarRulesWearableAssetType = {
	MaxNumber: number,
	Id: number,
	Name: string,
}

--[=[
	https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService#GetAvatarRules

	@interface AvatarRulesBodyColor
	.BrickColorId 0
	.NexColor string
	.Name string
	@within AvatarEditorUtils
]=]
export type AvatarRulesBodyColor = {
	BrickColorId: number,
	NexColor: string,
	Name: string,
}

--[=[
	@interface AvatarRuleDefaultClothingAssetLists
	.DefaultShirtAssetIds { number }
	.DefaultPantAssetIds { number }
	@within AvatarEditorUtils
]=]
export type AvatarRuleDefaultClothingAssetLists = {
	DefaultShirtAssetIds: { number },
	DefaultPantAssetIds: { number },
}

--[=[
	https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService#GetAvatarRules

	@interface AvatarRules
	.PlayerAvatarTypes "R6" | "R15" | string
	.Scales table
	.WearableAssetTypes": { AvatarRulesWearableAssetType }
	.BodyColorsPalette": { AvatarRulesBodyColor }
	.BasicBodyColorsPalette": { AvatarRulesBodyColor }
	.MinimumDeltaEBodyColorDifference number
	.ProportionsAndBodyTypeEnabledForUser boolean
	.DefaultClothingAssetLists": AvatarRuleDefaultClothingAssetLists
	.BundlesEnabledForUser boolean
	.EmotesEnabledForUser boolean
	@within AvatarEditorUtils
]=]
export type AvatarRules = {
	PlayerAvatarTypes: "R6" | "R15" | string,
	Scales: { [string]: number },
	WearableAssetTypes: { AvatarRulesWearableAssetType },
	BodyColorsPalette: { AvatarRulesBodyColor },
	BasicBodyColorsPalette: { AvatarRulesBodyColor },
	MinimumDeltaEBodyColorDifference: number,
	ProportionsAndBodyTypeEnabledForUser: boolean,
	DefaultClothingAssetLists: AvatarRuleDefaultClothingAssetLists,
	BundlesEnabledForUser: boolean,
	EmotesEnabledForUser: boolean,
}

--[=[
	Returns the platform Avatar rules for things such as scaling, default shirts and pants, number of wearable assets.

	https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService#GetAvatarRules

	@return Promise<AvatarRules>
]=]
function AvatarEditorUtils.promiseAvatarRules()
	return Promise.spawn(function(resolve, reject)
		local avatarRulesTable: AvatarRules
		local ok, err = pcall(function()
			avatarRulesTable = AvatarEditorService:GetAvatarRules()
		end)

		if not ok then
			return reject(err or "[AvatarEditorUtils.promiseAvatarRules] - Failed to GetAvatarRules")
		end

		if type(avatarRulesTable) ~= "table" then
			return reject("[AvatarEditorUtils.promiseAvatarRules] - Got bad humanoidDescription avatarRulesTable")
		end

		return resolve(avatarRulesTable)
	end)
end

--[=[
	This function returns if the Players.LocalPlayer has favorited the given bundle or asset.

	@param itemId number
	@param itemType AvatarItemType
	@return Promise<boolean>
]=]
function AvatarEditorUtils.promiseIsFavorited(itemId: number, itemType: Enum.AvatarItemType)
	assert(type(itemId) == "number", "Bad itemId")
	assert(EnumUtils.isOfType(Enum.AvatarItemType, itemType), "Bad itemType")

	return Promise.spawn(function(resolve, reject)
		local isFavorited: boolean
		local ok, err = pcall(function()
			isFavorited = AvatarEditorService:GetFavorite(itemId, itemType)
		end)

		if not ok then
			return reject(err or "[AvatarEditorUtils.promiseIsFavorited] - Failed to GetFavorite")
		end

		if type(isFavorited) ~= "boolean" then
			return reject(err, "[AvatarEditorUtils.promiseIsFavorited] - Not a boolean result for isFavorited")
		end

		return resolve(isFavorited)
	end)
end

--[=[
	This function returns if the Players.LocalPlayer has favorited the given bundle or asset.

	@param catalogSearchParams CatalogSearchParams
	@return Promise<CatalogPages>
]=]
function AvatarEditorUtils.promiseSearchCatalog(catalogSearchParams: CatalogSearchParams)
	assert(typeof(catalogSearchParams) == "CatalogSearchParams", "Bad catalogSearchParams")

	return Promise.spawn(function(resolve, reject)
		local catalogPages: CatalogPages
		local ok, err = pcall(function()
			catalogPages = AvatarEditorService:SearchCatalog(catalogSearchParams)
		end)

		if not ok then
			return reject(err or "[AvatarEditorUtils.promiseSearchCatalog] - Failed to GetFavorite")
		end

		if typeof(catalogPages) ~= "Instance" then
			return reject(err, "[AvatarEditorUtils.promiseSearchCatalog] - Not a boolean result for catalogPages")
		end

		return resolve(catalogPages)
	end)
end

--[=[
	Returns an InventoryPages object with information about owned items in the users inventory with the given AvatarAssetTypes.

	@param assetTypes { AvatarAssetType }
	@return Promise<InventoryPages>
]=]
function AvatarEditorUtils.promiseInventoryPages(assetTypes: { Enum.AvatarAssetType })
	assert(type(assetTypes) == "table", "Bad assetTypes")

	return Promise.spawn(function(resolve, reject)
		local inventoryPages
		local ok, err = pcall(function()
			inventoryPages = AvatarEditorService:GetInventory(assetTypes)
		end)

		if not ok then
			return reject(err or "[AvatarEditorUtils.promiseInventoryPages] - Failed to GetInventory")
		end

		if not (typeof(inventoryPages) == "Instance" and inventoryPages:IsA("InventoryPages")) then
			return reject("[AvatarEditorUtils.promiseInventoryPages] - Bad inventoryPages instance result")
		end

		return resolve(inventoryPages)
	end)
end

--[=[
	This function returns outfit data for the Players.LocalPlayer. This would be used with
	[Players.GetHumanoidDescriptionFromOutfitId] to update the players character to the outfit.
	Access to this would also depend on [AvatarEditorService.PromptAllowInventoryReadAccess]
	being accepted by the user.

	@param outfitSource OutfitSource
	@param outfitType OutfitType
	@return Promise<OutfitPages>
]=]
function AvatarEditorUtils.promiseOutfitPages(outfitSource: Enum.OutfitSource, outfitType: Enum.OutfitType)
	assert(EnumUtils.isOfType(Enum.OutfitSource, outfitSource), "Bad outfitSource")
	assert(EnumUtils.isOfType(Enum.OutfitType, outfitType), "Bad outfitType")

	return Promise.spawn(function(resolve, reject)
		local outfitPages: OutfitPages
		local ok, err = pcall(function()
			outfitPages = AvatarEditorService:GetOutfits(outfitSource, outfitSource, outfitType)
		end)

		if not ok then
			return reject(err or "[AvatarEditorUtils.promiseOutfitPages] - Failed to GetOutfits")
		end

		if not (typeof(outfitPages) == "Instance" and outfitPages:IsA("OutfitPages")) then
			return reject("[AvatarEditorUtils.promiseOutfitPages] - Bad outfitPages instance result")
		end

		return resolve(outfitPages)
	end)
end

--[=[
	This function returns a list of recommendations based on the given AssetType.

	https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService#GetRecommendedAssets

	:::warning
	This API surface currently returns "AvatarEditorService is not yet enabled" when queried outside
	of approved games.
	:::

	@param assetType AvatarAssetType
	@param contextAssetId number? -- Optional. if not provided just gives recommendations in general
	@return Promise<{ number }>
]=]
function AvatarEditorUtils.promiseRecommendedAssets(assetType: Enum.AvatarAssetType, contextAssetId: number?)
	assert(EnumUtils.isOfType(Enum.AvatarAssetType, assetType), "Bad assetType")
	assert(type(contextAssetId) == "number" or contextAssetId == nil, "Bad contextAssetId")

	contextAssetId = contextAssetId or 0

	return Promise.spawn(function(resolve, reject)
		local result: { number }
		local ok, err = pcall(function()
			result = AvatarEditorService:GetRecommendedAssets(assetType, contextAssetId)
		end)

		if not ok then
			return reject(err or "Failed to GetRecommendedAssets")
		end

		return resolve(result)
	end)
end

--[=[
	This function returns a list of recommended bundles for a given bundle id.

	@param bundleId number
	@return Promise<{ number }>
]=]
function AvatarEditorUtils.promiseRecommendedBundles(bundleId: number)
	assert(type(bundleId) == "number", "Bad bundleId")

	return Promise.spawn(function(resolve, reject)
		local recommendedBundleIds: { number }
		local ok, err = pcall(function()
			recommendedBundleIds = AvatarEditorService:GetRecommendedBundles(bundleId)
		end)

		if not ok then
			return reject(err or "Failed to GetRecommendedBundles")
		end

		if type(recommendedBundleIds) ~= "table" then
			return reject("Bad recommendedBundleIds (not a table)")
		end

		return resolve(recommendedBundleIds)
	end)
end

--[=[
	Prompts the Players.LocalPlayer to allow the developer to read what items the user has in their inventory and other
	avatar editor related information. The prompt needs to be confirmed by the user for the developer to use
	AvatarEditorService:GetInventory(), AvatarEditorService:GetOutfits() and AvatarEditorService:GetFavorite(). Permission
	does not persist between sessions.

	@return Promise<AvatarPromptResult>
]=]
function AvatarEditorUtils.promptAllowInventoryReadAccess()
	local maid = Maid.new()

	local promise = Promise.new()
	maid:GiveTask(promise)
	promise:Finally(function()
		maid:DoCleaning()
	end)

	maid:GiveTask(AvatarEditorService.PromptAllowInventoryReadAccessCompleted:Connect(function(avatarPromptResult)
		if avatarPromptResult == Enum.AvatarPromptResult.Success then
			promise:Resolve(avatarPromptResult)
		else
			promise:Reject(avatarPromptResult)
		end
	end))

	local ok, err = pcall(function()
		AvatarEditorService:PromptAllowInventoryReadAccess()
	end)

	if not ok then
		promise:Reject(err or "Failed to PromptAllowInventoryReadAccess")
	end

	if not RunService:IsRunning() then
		promise:Resolve()
	end

	return promise
end

--[=[
	Prompts the Players.LocalPlayer to save the given HumanoidDescription as an outfit.

	@param outfit HumanoidDescription
	@param rigType HumanoidRigType
	@return Promise<AvatarPromptResult>
]=]
function AvatarEditorUtils.promptCreateOutfit(outfit: HumanoidDescription, rigType: Enum.HumanoidRigType)
	assert(typeof(outfit) == "Instance" and outfit:IsA("HumanoidDescription"), "Bad outfit")
	assert(EnumUtils.isOfType(Enum.HumanoidRigType, rigType), "Bad rigType")

	local maid = Maid.new()

	local promise = Promise.new()
	maid:GiveTask(promise)
	promise:Finally(function()
		maid:DoCleaning()
	end)

	maid:GiveTask(AvatarEditorService.PromptCreateOutfitCompleted:Connect(function(avatarPromptResult, failureType)
		if avatarPromptResult == Enum.AvatarPromptResult.Success then
			promise:Resolve(avatarPromptResult)
		else
			promise:Reject(avatarPromptResult, failureType)
		end
	end))

	local ok, err = pcall(function()
		AvatarEditorService:PromptCreateOutfit(outfit, rigType)
	end)

	if not ok then
		promise:Reject(err or "Failed to PromptCreateOutfit")
	end

	return promise
end

--[=[
	Prompts the Players.LocalPlayer to delete the given outfit.

	@param outfitId number
	@return Promise<AvatarPromptResult>
]=]
function AvatarEditorUtils.promptDeleteOutfit(outfitId: number)
	assert(type(outfitId) == "number", "Bad outfitId")

	local maid = Maid.new()

	local promise = Promise.new()
	maid:GiveTask(promise)
	promise:Finally(function()
		maid:DoCleaning()
	end)

	maid:GiveTask(
		AvatarEditorService.PromptDeleteOutfitCompleted:Connect(function(avatarPromptResult: Enum.AvatarPromptResult)
			if avatarPromptResult == Enum.AvatarPromptResult.Success then
				promise:Resolve(avatarPromptResult)
			else
				promise:Reject(avatarPromptResult)
			end
		end)
	)

	local ok, err = pcall(function()
		AvatarEditorService:PromptDeleteOutfit(outfitId)
	end)

	if not ok then
		promise:Reject(err or "Failed to PromptDeleteOutfit")
	end

	return promise
end

--[=[
	Prompts the Players.LocalPlayer to delete the given outfit.

	@param outfitId number
	@return Promise<AvatarPromptResult>
]=]
function AvatarEditorUtils.promptRenameOutfit(outfitId: number)
	assert(type(outfitId) == "number", "Bad outfitId")

	local maid = Maid.new()

	local promise = Promise.new()
	maid:GiveTask(promise)
	promise:Finally(function()
		maid:DoCleaning()
	end)

	maid:GiveTask(
		AvatarEditorService.PromptRenameOutfitCompleted:Connect(function(avatarPromptResult: Enum.AvatarPromptResult)
			if avatarPromptResult == Enum.AvatarPromptResult.Success then
				promise:Resolve(avatarPromptResult)
			else
				promise:Reject(avatarPromptResult)
			end
		end)
	)

	local ok, err = pcall(function()
		AvatarEditorService:PromptRenameOutfit(outfitId)
	end)

	if not ok then
		promise:Reject(err or "Failed to PromptRenameOutfit")
	end

	return promise
end

--[=[
	@param humanoidDescription HumanoidDescription
	@param rigType HumanoidRigType
	@return Promise<AvatarPromptResult>
]=]
function AvatarEditorUtils.promptSaveAvatar(humanoidDescription: HumanoidDescription, rigType: Enum.HumanoidRigType)
	assert(
		typeof(humanoidDescription) == "Instance" and humanoidDescription:IsA("HumanoidDescription"),
		"Bad humanoidDescription"
	)
	assert(EnumUtils.isOfType(Enum.HumanoidRigType, rigType), "Bad rigType")

	local maid = Maid.new()

	local promise = Promise.new()
	maid:GiveTask(promise)
	promise:Finally(function()
		maid:DoCleaning()
	end)

	maid:GiveTask(
		AvatarEditorService.PromptSaveAvatarCompleted:Connect(function(avatarPromptResult: Enum.AvatarPromptResult)
			if avatarPromptResult == Enum.AvatarPromptResult.Success then
				promise:Resolve(avatarPromptResult)
			else
				promise:Reject(avatarPromptResult)
			end
		end)
	)

	local ok, err = pcall(function()
		AvatarEditorService:PromptSaveAvatar(humanoidDescription, rigType)
	end)

	if not ok then
		promise:Reject(err or "Failed to PromptSaveAvatar")
	end

	return promise
end

--[=[
	This function prompts the Players.LocalPlayer to favorite or unfavorite the given asset or bundle.

	@param itemId number
	@param itemType Enum.AvatarItemType
	@param shouldFavorite boolean
	@return Promise<AvatarPromptResult>
]=]
function AvatarEditorUtils.promptSetFavorite(itemId: number, itemType: Enum.AvatarItemType, shouldFavorite: boolean)
	assert(type(itemId) == "number", "Bad itemId")
	assert(EnumUtils.isOfType(Enum.AvatarItemType, itemType), "Bad itemType")
	assert(type(shouldFavorite) == "boolean", "Bad shouldFavorite")

	local maid = Maid.new()

	local promise = Promise.new()
	maid:GiveTask(promise)
	promise:Finally(function()
		maid:DoCleaning()
	end)

	maid:GiveTask(
		AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(avatarPromptResult: Enum.AvatarPromptResult)
			if avatarPromptResult == Enum.AvatarPromptResult.Success then
				promise:Resolve(avatarPromptResult)
			else
				promise:Reject(avatarPromptResult)
			end
		end)
	)

	local ok, err = pcall(function()
		AvatarEditorService:PromptSetFavorite(itemId, itemType, shouldFavorite)
	end)

	if not ok then
		promise:Reject(err or "Failed to PromptSetFavorite")
	end

	return promise
end

--[=[
	Prompts the Players.LocalPlayer to update the given outfit with the given HumanoidDescription.

	@param outfitId number
	@param updatedOutfit HumanoidDescription
	@param rigType HumanoidRigType
	@return Promise<AvatarPromptResult>
]=]
function AvatarEditorUtils.promptUpdateOutfit(outfitId: number, updatedOutfit: HumanoidDescription, rigType: Enum.HumanoidRigType)
	assert(type(outfitId) == "number", "Bad outfitId")
	assert(typeof(updatedOutfit) == "Instance" and updatedOutfit:IsA("HumanoidDescription"), "Bad updatedOutfit")
	assert(EnumUtils.isOfType(Enum.HumanoidRigType, rigType), "Bad rigType")

	local maid = Maid.new()

	local promise = Promise.new()
	maid:GiveTask(promise)
	promise:Finally(function()
		maid:DoCleaning()
	end)

	maid:GiveTask(AvatarEditorService.PromptUpdateOutfitCompleted:Connect(function(avatarPromptResult: Enum.AvatarPromptResult)
		if avatarPromptResult == Enum.AvatarPromptResult.Success then
			promise:Resolve(avatarPromptResult)
		else
			promise:Reject(avatarPromptResult)
		end
	end))

	local ok, err = pcall(function()
		AvatarEditorService:PromptUpdateOutfit(outfitId, updatedOutfit, rigType)
	end)

	if not ok then
		promise:Reject(err or "[AvatarEditorUtils.promptUpdateOutfit] - Failed to PromptUpdateOutfit")
	end

	return promise
end

return AvatarEditorUtils