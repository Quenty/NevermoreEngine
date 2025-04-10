--!strict
--[=[
	Base class for player settings.

	@class PlayerSettingsBase
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local RxAttributeUtils = require("RxAttributeUtils")
local SettingDefinition = require("SettingDefinition")
local Rx = require("Rx")
local DataStoreStringUtils = require("DataStoreStringUtils")
local _ServiceBag = require("ServiceBag")

local PlayerSettingsBase = setmetatable({}, BaseObject)
PlayerSettingsBase.ClassName = "PlayerSettingsBase"
PlayerSettingsBase.__index = PlayerSettingsBase

export type PlayerSettingsBase = typeof(setmetatable(
	{} :: {
		_obj: Folder,
		_serviceBag: _ServiceBag.ServiceBag,
	},
	{} :: typeof({ __index = PlayerSettingsBase })
)) & BaseObject.BaseObject

--[=[
	Base class for player settings

	@param folder Folder
	@param serviceBag ServiceBag
	@return PlayerSettingsBase
]=]
function PlayerSettingsBase.new(folder: Folder, serviceBag: _ServiceBag.ServiceBag): PlayerSettingsBase
	local self: PlayerSettingsBase = setmetatable(BaseObject.new(folder) :: any, PlayerSettingsBase)

	self._serviceBag = assert(serviceBag, "No serviceBag")

	return self
end

--[=[
	Gets the player for this setting
	@return Player
]=]
function PlayerSettingsBase.GetPlayer(self: PlayerSettingsBase): Player?
	return self._obj:FindFirstAncestorWhichIsA("Player")
end

--[=[
	Gets the settings folder
	@return Folder
]=]
function PlayerSettingsBase.GetFolder(self: PlayerSettingsBase): Folder
	return self._obj
end

--[=[
	If you want to use a setting value object instead, this works... Otherwise
	consider using the setting definitions in a centralized location.

	@param settingName string
	@param defaultValue any
	@return SettingProperty
]=]
function PlayerSettingsBase.GetSettingProperty(self: PlayerSettingsBase, settingName: string, defaultValue)
	assert(type(settingName) == "string", "Bad settingName")
	assert(defaultValue ~= nil, "defaultValue cannot be nil")

	self:EnsureInitialized(settingName, defaultValue)

	return SettingDefinition.new(settingName, defaultValue):GetSettingProperty(self._serviceBag, self:GetPlayer())
end

--[=[
	Gets the setting value for the given name

	@param settingName string
	@param defaultValue any
	@return any
]=]
function PlayerSettingsBase.GetValue(self: PlayerSettingsBase, settingName: string, defaultValue)
	assert(type(settingName) == "string", "Bad settingName")
	assert(defaultValue ~= nil, "defaultValue cannot be nil")
	assert(DataStoreStringUtils.isValidUTF8(settingName), "Bad settingName")

	local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

	self:EnsureInitialized(settingName, defaultValue)

	local value = PlayerSettingsUtils.decodeForAttribute(self._obj:GetAttribute(attributeName))
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
function PlayerSettingsBase.SetValue(self: PlayerSettingsBase, settingName: string, value)
	assert(type(settingName) == "string", "Bad settingName")
	assert(DataStoreStringUtils.isValidUTF8(settingName), "Bad settingName")

	local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

	self._obj:SetAttribute(attributeName, PlayerSettingsUtils.encodeForAttribute(value))
end

--[=[
	Sets the setting value for the given name

	@param settingName string
	@param defaultValue any
	@return Observable<any>
]=]
function PlayerSettingsBase.ObserveValue(self: PlayerSettingsBase, settingName: string, defaultValue)
	assert(type(settingName) == "string", "Bad settingName")
	assert(defaultValue ~= nil, "defaultValue cannot be nil")
	assert(DataStoreStringUtils.isValidUTF8(settingName), "Bad settingName")

	local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

	self:EnsureInitialized(settingName, defaultValue)

	return RxAttributeUtils.observeAttribute(self._obj, attributeName, defaultValue):Pipe({
		Rx.map(PlayerSettingsUtils.decodeForAttribute) :: any,
	}) :: any
end

--[=[
	Restores the default value for the setting

	@param settingName string
	@param defaultValue T
]=]
function PlayerSettingsBase.RestoreDefault(self: PlayerSettingsBase, settingName: string, defaultValue)
	assert(type(settingName) == "string", "Bad settingName")
	assert(DataStoreStringUtils.isValidUTF8(settingName), "Bad settingName")

	-- TODO: Maybe something more sophisticated?
	self:SetValue(settingName, defaultValue)
end

--[=[
	Ensures the setting is initialized on the server or client

	@param settingName string
	@param defaultValue any
]=]
function PlayerSettingsBase.EnsureInitialized(_self: PlayerSettingsBase, settingName: string, defaultValue)
	assert(type(settingName) == "string", "Bad settingName")
	assert(defaultValue ~= nil, "defaultValue cannot be nil")
	assert(DataStoreStringUtils.isValidUTF8(settingName), "Bad settingName")

	-- noop
end

return PlayerSettingsBase