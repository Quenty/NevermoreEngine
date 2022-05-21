--[=[
	@class PlayerSettingsBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local RxAttributeUtils = require("RxAttributeUtils")
local SettingDefinition = require("SettingDefinition")

local PlayerSettingsBase = setmetatable({}, BaseObject)
PlayerSettingsBase.ClassName = "PlayerSettingsBase"
PlayerSettingsBase.__index = PlayerSettingsBase

function PlayerSettingsBase.new(obj, serviceBag)
	local self = setmetatable(BaseObject.new(obj), PlayerSettingsBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

--[=[
	Gets the player for this setting
	@return Player
]=]
function PlayerSettingsBase:GetPlayer()
	return self._obj.Parent
end

--[=[
	Gets the settings folder
	@return Folder
]=]
function PlayerSettingsBase:GetFolder()
	return self._obj
end

--[=[
	If you want to use a setting value object instead, this works... Otherwise
	consider using the setting definitions in a centralized location.

	@param settingName string
	@param defaultValue any
	@return SettingProperty
]=]
function PlayerSettingsBase:GetSetting(settingName, defaultValue)
	assert(type(settingName) == "string", "Bad settingName")
	assert(defaultValue ~= nil, "defaultValue cannot be nil")

	self:EnsureInitialized(settingName, defaultValue)

	return SettingDefinition.new(settingName, defaultValue):Get(self._serviceBag, self:GetPlayer())
end

--[=[
	Gets the setting value for the given name

	@param settingName string
	@param defaultValue any
	@return any
]=]
function PlayerSettingsBase:GetValue(settingName, defaultValue)
	assert(type(settingName) == "string", "Bad settingName")
	assert(defaultValue ~= nil, "defaultValue cannot be nil")

	local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

	self:EnsureInitialized(settingName, defaultValue)

	local value = self._obj:GetAttribute(attributeName)
	if value == nil then
		return defaultValue
	end

	return value
end

--[=[
	Sets the setting value for the given name

	@param settingName string
	@param value any
	@return any
]=]
function PlayerSettingsBase:SetValue(settingName, value)
	assert(type(settingName) == "string", "Bad settingName")

	local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

	self._obj:SetAttribute(attributeName, value)
end

--[=[
	Sets the setting value for the given name

	@param settingName string
	@param defaultValue any
	@return Observable<any>
]=]
function PlayerSettingsBase:ObserveValue(settingName, defaultValue)
	assert(type(settingName) == "string", "Bad settingName")
	assert(defaultValue ~= nil, "defaultValue cannot be nil")

	local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

	self:EnsureInitialized(settingName, defaultValue)

	return RxAttributeUtils.observeAttribute(self._obj, attributeName, defaultValue)
end

function PlayerSettingsBase:RestoreDefault(settingName, defaultValue)
	-- TODO: Maybe something more sophisticated?
	self:SetValue(settingName, defaultValue)
end

--[=[
	Ensures the setting is initialized on the server or client

	@param settingName string
	@param defaultValue any
]=]
function PlayerSettingsBase:EnsureInitialized(settingName, defaultValue)
	assert(type(settingName) == "string", "Bad settingName")
	assert(defaultValue ~= nil, "defaultValue cannot be nil")

	-- noop
end

return PlayerSettingsBase