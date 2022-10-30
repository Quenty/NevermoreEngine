--[=[
	Wraps the rbxthumb URL api surface to generate a URL for a thumbnail on the cloud.

	These thumbnails are automatically batched for performance.

	@class RbxThumbUtils
]=]

local RbxThumbUtils = {}

--[=[
	Gets a thumbnail URL for a given content type and id

	https://devforum.roblox.com/t/new-contentid-format-for-easy-thumbnail-loading/357335
	https://create.roblox.com/docs/studio/asset-types#rbxthumb

	Type:               Supported Sizes:
	"Asset"             150x150, 420x420
	"Avatar"            100x100, 352x352, 720x720
	"AvatarHeadShot"    48x48,   60x60,   150x150
	"BadgeIcon"         150x150
	"BundleThumbnail"   150x150, 420x420
	"GameIcon"          50x50,   150x150
	"GamePass"          150x150
	"GroupIcon"         150x150, 420x420
	"Outfit"            150x150, 420x420

	@param thumbnailType ThumbnailType
	@param targetId number
	@param width number
	@param height number
	@return string
]=]
function RbxThumbUtils.getThumbnailUrl(thumbnailType, targetId, width, height)
	assert(type(thumbnailType) == "string", "Bad thumbnailType")
	assert(type(targetId) == "number", "Bad targetId")
	assert(type(width) == "number", "Bad width")
	assert(type(height) == "number", "Bad height")

	return string.format("rbxthumb://type=%s&id=%d&w=%d&h=%d", thumbnailType, targetId, width, height)
end

--[=[
	Gets a Asset URL for use in an image label or other rendering application.

	Supported sizes: 150x150, 420x420

	@param targetId number
	@param width number?
	@param height number?
	@return string
]=]
function RbxThumbUtils.getAssetThumbnailUrl(targetId, width, height)
	assert(type(targetId) == "number", "Bad targetId")

	width = width or 150
	height = height or 150

	return RbxThumbUtils.getThumbnailUrl("Asset", targetId, width, height)
end

--[=[
	Gets a Avatar URL for use in an image label or other rendering application.

	Supported sizes: 100x100, 352x352, 720x720

	@param targetId number
	@param width number?
	@param height number?
	@return string
]=]
function RbxThumbUtils.getAvatarThumbnailUrl(targetId, width, height)
	assert(type(targetId) == "number", "Bad targetId")

	width = width or 150
	height = height or 150

	return RbxThumbUtils.getThumbnailUrl("Avatar", targetId, width, height)
end

--[=[
	Gets a AvatarHeadShot URL for use in an image label or other rendering application.

	Supported sizes: 48x48, 60x60, 150x150

	@param targetId number
	@param width number?
	@param height number?
	@return string
]=]
function RbxThumbUtils.getAvatarHeadShotThumbnailUrl(targetId, width, height)
	assert(type(targetId) == "number", "Bad targetId")

	width = width or 150
	height = height or 150

	return RbxThumbUtils.getThumbnailUrl("AvatarHeadShot", targetId, width, height)
end

--[=[
	Gets a BadgeIcon URL for use in an image label or other rendering application.

	Supported sizes: 150x150

	@param targetId number
	@param width number?
	@param height number?
	@return string
]=]
function RbxThumbUtils.getBadgeIconThumbnailUrl(targetId, width, height)
	assert(type(targetId) == "number", "Bad targetId")

	width = width or 150
	height = height or 150

	return RbxThumbUtils.getThumbnailUrl("BadgeIcon", targetId, width, height)
end

--[=[
	Gets a BundleThumbnail URL for use in an image label or other rendering application.

	Supported sizes: 150x150, 420x420

	@param targetId number
	@param width number?
	@param height number?
	@return string
]=]
function RbxThumbUtils.getBundleThumbnailThumbnailUrl(targetId, width, height)
	assert(type(targetId) == "number", "Bad targetId")

	width = width or 150
	height = height or 150

	return RbxThumbUtils.getThumbnailUrl("BundleThumbnail", targetId, width, height)
end

--[=[
	Gets a GameIcon URL for use in an image label or other rendering application.

	Supported sizes: 50x50, 150x150

	@param targetId number
	@param width number?
	@param height number?
	@return string
]=]
function RbxThumbUtils.getGameIconThumbnailUrl(targetId, width, height)
	assert(type(targetId) == "number", "Bad targetId")

	width = width or 150
	height = height or 150

	return RbxThumbUtils.getThumbnailUrl("GameIcon", targetId, width, height)
end

--[=[
	Gets a GamePass URL for use in an image label or other rendering application.

	Supported sizes: 150x150

	@param targetId number
	@param width number?
	@param height number?
	@return string
]=]
function RbxThumbUtils.getGamePassThumbnailUrl(targetId, width, height)
	assert(type(targetId) == "number", "Bad targetId")

	width = width or 150
	height = height or 150

	return RbxThumbUtils.getThumbnailUrl("GamePass", targetId, width, height)
end

--[=[
	Gets a GroupIcon URL for use in an image label or other rendering application.

	Supported sizes: 150x150, 420x420

	@param targetId number
	@param width number?
	@param height number?
	@return string
]=]
function RbxThumbUtils.getGroupIconThumbnailUrl(targetId, width, height)
	assert(type(targetId) == "number", "Bad targetId")

	width = width or 150
	height = height or 150

	return RbxThumbUtils.getThumbnailUrl("GroupIcon", targetId, width, height)
end

--[=[
	Gets a Outfit URL for use in an image label or other rendering application.

	Supported sizes: 150x150, 420x420

	@param targetId number
	@param width number?
	@param height number?
	@return string
]=]
function RbxThumbUtils.getOutfitThumbnailUrl(targetId, width, height)
	assert(type(targetId) == "number", "Bad targetId")

	width = width or 150
	height = height or 150

	return RbxThumbUtils.getThumbnailUrl("Outfit", targetId, width, height)
end


return RbxThumbUtils