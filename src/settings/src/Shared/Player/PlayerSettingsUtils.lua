--[=[
	@class PlayerSettingsUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerSettingsConstants = require("PlayerSettingsConstants")
local String = require("String")
local RxBinderUtils = require("RxBinderUtils")
local BinderUtils = require("BinderUtils")
local Binder = require("Binder")
local RxStateStackUtils = require("RxStateStackUtils")

local PlayerSettingsUtils = {}

function PlayerSettingsUtils.create(binder)
	assert(Binder.isBinder(binder), "No binder")

	local playerSettings = Instance.new("Folder")
	playerSettings.Name = PlayerSettingsConstants.PLAYER_SETTINGS_NAME

	binder:Bind(playerSettings)

	return playerSettings
end

function PlayerSettingsUtils.observePlayerSettingsBrio(binder, player)
	assert(Binder.isBinder(binder), "No binder")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return RxBinderUtils.observeBoundChildClassBrio(binder, player)
end

function PlayerSettingsUtils.observePlayerSettings(binder, player)
	return RxBinderUtils.observeBoundChildClassBrio(binder, player):Pipe({
		RxStateStackUtils.topOfStack()
	})
end

function PlayerSettingsUtils.getPlayerSettings(binder, player)
	assert(Binder.isBinder(binder), "No binder")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return BinderUtils.findFirstChild(binder, player)
end

function PlayerSettingsUtils.getAttributeName(settingName)
	assert(type(settingName) == "string", "Bad settingName")

	return PlayerSettingsConstants.SETTING_ATTRIBUTE_PREFIX .. settingName
end

function PlayerSettingsUtils.getSettingName(attributeName)
	assert(type(attributeName) == "string", "Bad attributeName")

	attributeName = String.removePrefix(attributeName, PlayerSettingsConstants.SETTING_ATTRIBUTE_PREFIX)
	return attributeName
end

function PlayerSettingsUtils.isSettingAttribute(attributeName)
	assert(type(attributeName) == "string", "Bad attributeName")

	return String.startsWith(attributeName, PlayerSettingsConstants.SETTING_ATTRIBUTE_PREFIX)
end

function PlayerSettingsUtils.encodeForNetwork(settingValue)
	assert(settingValue ~= "<NIL_SETTING_VALUE>", "Cannot have setting as <NIL_SETTING_VALUE>")

	if settingValue == nil then
		return "<NIL_SETTING_VALUE>"
	else
		return settingValue
	end
end

function PlayerSettingsUtils.decodeForNetwork(settingValue)
	if settingValue == "<NIL_SETTING_VALUE>" then
		return nil
	else
		return settingValue
	end
end


return PlayerSettingsUtils
