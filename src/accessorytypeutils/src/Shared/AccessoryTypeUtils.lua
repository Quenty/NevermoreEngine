--!strict
--[=[
	@class AccessoryTypeUtils
]=]

local require = require(script.Parent.loader).load(script)

local EnumUtils = require("EnumUtils")

local AvatarEditorService = game:GetService("AvatarEditorService")

local AccessoryTypeUtils = {}

--[=[
	Converts an enum value (retrieved from AvatarEditorService) into a proper enum if possible

	@param avatarAssetType Enum.AvatarAssetType
	@return Enum.AccessoryType?
]=]
function AccessoryTypeUtils.tryGetAccessoryType(avatarAssetType: Enum.AvatarAssetType): (Enum.AccessoryType?, string?)
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

--[=[
	Converts a string into an enum value

	@param accessoryType string
	@return Enum.AccessoryType
]=]
function AccessoryTypeUtils.getAccessoryTypeFromName(accessoryType: string): Enum.AccessoryType
	for _, enumItem in Enum.AccessoryType:GetEnumItems() do
		if enumItem.Name == accessoryType then
			return enumItem
		end
	end

	return Enum.AccessoryType.Unknown
end

--[=[
	Converts an enum value (retrieved from MarketplaceService) into a proper enum if possible

	@param assetTypeId number
	@return Enum.AssetType?
]=]
function AccessoryTypeUtils.convertAssetTypeIdToAssetType(assetTypeId: number): Enum.AssetType?
	assert(type(assetTypeId) == "number", "Bad assetTypeId")

	return EnumUtils.toEnum(Enum.AssetType, assetTypeId) :: any
end

--[=[
	Converts an enum value (retrieved from MarketplaceService) into a proper enum if possible

	@param avatarAssetTypeId number
	@return Enum.AvatarAssetType?
]=]
function AccessoryTypeUtils.convertAssetTypeIdToAvatarAssetType(avatarAssetTypeId: number): Enum.AvatarAssetType?
	assert(type(avatarAssetTypeId) == "number", "Bad avatarAssetTypeId")

	return EnumUtils.toEnum(Enum.AvatarAssetType, avatarAssetTypeId) :: any
end

return AccessoryTypeUtils