--[=[
	Canonical RbxThumbnailTypes
	@class RbxThumbnailTypes
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

return Table.readonly({
	ASSET = "Asset";
	AVATAR = "Avatar";
	AVATAR_HEAD_SHOT = "AvatarHeadShot";
	BADGE = "BadgeIcon";
	BUNDLE = "BundleThumbnail";
	GAME_ICON = "GameIcon";
	GAME_PASS = "GamePass";
	GROUP_ICON = "GroupIcon";
	OUTFIT = "Outfit";
})