--[=[
	@class AccessoryTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local EnumUtils = require("EnumUtils")

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
function AccessoryTypeUtils.convertAssetTypeIdToAssetType(assetTypeId: number): AssetType?
	assert(type(assetTypeId) == "number", "Bad assetTypeId")

	return EnumUtils.toEnum(Enum.AssetType, assetTypeId)
end

--[=[
	Converts an enum value (retrieved from MarketplaceService) into a proper enum if possible

	@param avatarAssetTypeId number
	@return AvatarAssetType | nil
]=]
function AccessoryTypeUtils.convertAssetTypeIdToAvatarAssetType(avatarAssetTypeId: number): AvatarAssetType?
	assert(type(avatarAssetTypeId) == "number", "Bad avatarAssetTypeId")

	return EnumUtils.toEnum(Enum.AvatarAssetType, avatarAssetTypeId)
end

return AccessoryTypeUtils