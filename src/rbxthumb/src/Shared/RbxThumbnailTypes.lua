--!strict
--[=[
	Canonical RbxThumbnailTypes
	@class RbxThumbnailTypes
]=]

local require = require(script.Parent.loader).load(script)

local SimpleEnum = require("SimpleEnum")

export type RbxThumbnailType =
	"Asset"
	| "Avatar"
	| "AvatarHeadShot"
	| "BadgeIcon"
	| "BundleThumbnail"
	| "GameIcon"
	| "GamePass"
	| "GroupIcon"
	| "Outfit"

return SimpleEnum.new({
	ASSET = "Asset" :: "Asset",
	AVATAR = "Avatar" :: "Avatar",
	AVATAR_HEAD_SHOT = "AvatarHeadShot" :: "AvatarHeadShot",
	BADGE = "BadgeIcon" :: "BadgeIcon",
	BUNDLE = "BundleThumbnail" :: "BundleThumbnail",
	GAME_ICON = "GameIcon" :: "GameIcon",
	GAME_PASS = "GamePass" :: "GamePass",
	GROUP_ICON = "GroupIcon" :: "GroupIcon",
	OUTFIT = "Outfit" :: "Outfit",
})
