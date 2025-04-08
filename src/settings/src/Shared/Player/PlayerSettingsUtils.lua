--!strict
--[=[
	Utility helpers to work with settings.

	@class PlayerSettingsUtils
]=]

local require = require(script.Parent.loader).load(script)

local PlayerSettingsConstants = require("PlayerSettingsConstants")
local String = require("String")
local EnumUtils = require("EnumUtils")
local DataStoreStringUtils = require("DataStoreStringUtils")

local PlayerSettingsUtils = {}

--[=[
	Creates a new player settings

	@return Folder
]=]
function PlayerSettingsUtils.create(): Folder
	local playerSettings = Instance.new("Folder")
	playerSettings.Name = PlayerSettingsConstants.PLAYER_SETTINGS_NAME
	playerSettings:AddTag("PlayerSettings")

	return playerSettings
end

--[=[
	Gets the attribute name for a setting

	@param settingName string
	@return string
]=]
function PlayerSettingsUtils.getAttributeName(settingName: string): string
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
function PlayerSettingsUtils.getSettingName(attributeName: string): string
	assert(type(attributeName) == "string", "Bad attributeName")

	return String.removePrefix(attributeName, PlayerSettingsConstants.SETTING_ATTRIBUTE_PREFIX)
end

--[=[
	Returns true if the attribute name is a settings attribute

	@param attributeName string
	@return string
]=]
function PlayerSettingsUtils.isSettingAttribute(attributeName: string): boolean
	assert(type(attributeName) == "string", "Bad attributeName")

	return String.startsWith(attributeName, PlayerSettingsConstants.SETTING_ATTRIBUTE_PREFIX)
end

--[=[
	Encodes a given value for network transfer

	@param settingValue any
	@return any
]=]
function PlayerSettingsUtils.encodeForNetwork(settingValue: any): any
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
function PlayerSettingsUtils.decodeForNetwork(settingValue: any): any
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
function PlayerSettingsUtils.decodeForAttribute(settingValue: any): any
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
function PlayerSettingsUtils.encodeForAttribute(settingValue: any): any
	if typeof(settingValue) == "EnumItem" then
		return EnumUtils.encodeAsString(settingValue)
	else
		return settingValue
	end
end

return PlayerSettingsUtils
