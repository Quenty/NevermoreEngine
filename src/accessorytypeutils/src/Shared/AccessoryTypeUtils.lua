--[=[
	@class AccessoryTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local AvatarEditorService = game:GetService("AvatarEditorService")

local AccessoryTypeUtils = {}

function AccessoryTypeUtils.tryGetAccessoryType(avatarAssetType: AvatarAssetType): (AccessoryType?, string?)
	if not avatarAssetType then
		return nil, "No avatarAssetType"
	end

	local accessoryType
	local ok, err = pcall(function()
		accessoryType = AvatarEditorService:GetAccessoryType(avatarAssetType)
	end)
	if not ok then
		return nil, err or "Failed to GetAccessoryType from avatarAssetType"
	end

	return accessoryType
end

function AccessoryTypeUtils.getAccessoryTypeFromName(accessoryType: string): AccessoryType
	for _, enumItem in pairs(Enum.AccessoryType:GetEnumItems()) do
		if enumItem.Name == accessoryType then
			return enumItem
		end
	end

	return Enum.AccessoryType.Unknown
end

--[=[
	Converts an enum value (retrieved from MarketplaceService) into a proper enum if possible

	@param assetTypeId number
	@return AssetType | nl
]=]
function AccessoryTypeUtils.convertAssetTypeIdToAssetType(assetTypeId): AssetType
	assert(type(assetTypeId) == "number", "Bad assetTypeId")

	for _, enumItem in pairs(Enum.AssetType:GetEnumItems()) do
		if enumItem.Value == assetTypeId then
			return enumItem
		end
	end

	return nil
end

--[=[
	Converts an enum value (retrieved from MarketplaceService) into a proper enum if possible

	@param assetTypeId number
	@return AvatarAssetType | nil
]=]
function AccessoryTypeUtils.convertAssetTypeIdToAvatarAssetType(assetTypeId): AvatarAssetType
	assert(type(assetTypeId) == "number", "Bad assetTypeId")

	for _, enumItem in pairs(Enum.AvatarAssetType:GetEnumItems()) do
		if enumItem.Value == assetTypeId then
			return enumItem
		end
	end

	return nil
end

return AccessoryTypeUtils