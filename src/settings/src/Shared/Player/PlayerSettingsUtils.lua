--[=[
	Utility helpers to work with settings.

	@class PlayerSettingsUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerSettingsConstants = require("PlayerSettingsConstants")
local String = require("String")
local RxBinderUtils = require("RxBinderUtils")
local BinderUtils = require("BinderUtils")
local Binder = require("Binder")
local RxStateStackUtils = require("RxStateStackUtils")
local EnumUtils = require("EnumUtils")
local DataStoreStringUtils = require("DataStoreStringUtils")

local PlayerSettingsUtils = {}

--[=[
	Creates a new player settings

	@return Folder
]=]
function PlayerSettingsUtils.create()
	local playerSettings = Instance.new("Folder")
	playerSettings.Name = PlayerSettingsConstants.PLAYER_SETTINGS_NAME
	playerSettings:AddTag("PlayerSettings")

	return playerSettings
end

--[=[
	Observe a player settings for a player.

	@param binder Binder<PlayerSettings>
	@param player Player
	@return Observable<PlayerSettings>
]=]
function PlayerSettingsUtils.observePlayerSettingsBrio(binder, player)
	assert(Binder.isBinder(binder), "No binder")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return RxBinderUtils.observeBoundChildClassBrio(binder, player)
end

--[=[
	Observe a player's latest settings

	@param binder Binder<PlayerSettings>
	@param player Player
	@return Observable<PlayerSettings>
]=]
function PlayerSettingsUtils.observePlayerSettings(binder, player)
	return RxBinderUtils.observeBoundChildClassBrio(binder, player):Pipe({
		RxStateStackUtils.topOfStack()
	})
end

--[=[
	Gets a player's latest settings

	@param binder Binder<PlayerSettings>
	@param player Player
	@return PlayerSettings
]=]
function PlayerSettingsUtils.getPlayerSettings(binder, player)
	assert(Binder.isBinder(binder), "No binder")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return BinderUtils.findFirstChild(binder, player)
end

--[=[
	Gets the attribute name for a setting

	@param settingName string
	@return string
]=]
function PlayerSettingsUtils.getAttributeName(settingName)
	assert(type(settingName) == "string", "Bad settingName")
	assert(DataStoreStringUtils.isValidUTF8(settingName), "Bad settingName")

	return PlayerSettingsConstants.SETTING_ATTRIBUTE_PREFIX .. settingName
end

--[=[
	Gets the settings name from an attribute. May return a string
	that cannot be loaded into datastore.

	@param attributeName string
	@return string
]=]
function PlayerSettingsUtils.getSettingName(attributeName)
	assert(type(attributeName) == "string", "Bad attributeName")

	return String.removePrefix(attributeName, PlayerSettingsConstants.SETTING_ATTRIBUTE_PREFIX)
end

--[=[
	Returns true if the attribute name is a settings attribute

	@param attributeName string
	@return string
]=]
function PlayerSettingsUtils.isSettingAttribute(attributeName)
	assert(type(attributeName) == "string", "Bad attributeName")

	return String.startsWith(attributeName, PlayerSettingsConstants.SETTING_ATTRIBUTE_PREFIX)
end

--[=[
	Encodes a given value for network transfer

	@param settingValue any
	@return any
]=]
function PlayerSettingsUtils.encodeForNetwork(settingValue)
	assert(settingValue ~= "<NIL_SETTING_VALUE>", "Cannot have setting as <NIL_SETTING_VALUE>")

	if settingValue == nil then
		return "<NIL_SETTING_VALUE>"
	elseif typeof(settingValue) == "EnumItem" then
		return EnumUtils.encodeAsString(settingValue)
	else
		return settingValue
	end
end

--[=[
	Decodes a given value from network transfer

	@param settingValue any
	@return any
]=]
function PlayerSettingsUtils.decodeForNetwork(settingValue)
	if settingValue == "<NIL_SETTING_VALUE>" then
		return nil
	elseif EnumUtils.isEncodedEnum(settingValue) then
		return EnumUtils.decodeFromString(settingValue)
	else
		return settingValue
	end
end

--[=[
	Decodes a given value for attribute storage

	@param settingValue any
	@return any
]=]
function PlayerSettingsUtils.decodeForAttribute(settingValue)
	if EnumUtils.isEncodedEnum(settingValue) then
		return EnumUtils.decodeFromString(settingValue)
	else
		return settingValue
	end
end

--[=[
	Encodes a given value for attribute storage

	@param settingValue any
	@return any
]=]
function PlayerSettingsUtils.encodeForAttribute(settingValue)
	if typeof(settingValue) == "EnumItem" then
		return EnumUtils.encodeAsString(settingValue)
	else
		return settingValue
	end
end

return PlayerSettingsUtils
