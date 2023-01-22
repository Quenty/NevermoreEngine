--[=[
	@class PlayerSettings
]=]

local require = require(script.Parent.loader).load(script)

local PlayerSettingsBase = require("PlayerSettingsBase")
local PlayerSettingsConstants = require("PlayerSettingsConstants")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local SettingRegistryServiceShared = require("SettingRegistryServiceShared")
local DataStoreStringUtils = require("DataStoreStringUtils")

local PlayerSettings = setmetatable({}, PlayerSettingsBase)
PlayerSettings.ClassName = "PlayerSettings"
PlayerSettings.__index = PlayerSettings

function PlayerSettings.new(obj, serviceBag)
	local self = setmetatable(PlayerSettingsBase.new(obj, serviceBag), PlayerSettings)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._settingRegistryServiceShared = self._serviceBag:GetService(SettingRegistryServiceShared)

	self._remoteFunction = Instance.new("RemoteFunction")
	self._remoteFunction.Name = PlayerSettingsConstants.REMOTE_FUNCTION_NAME
	self._remoteFunction.Archivable = false
	self._remoteFunction.Parent = self._obj
	self._maid:GiveTask(self._remoteFunction)

	self._remoteFunction.OnServerInvoke = function(...)
		return self:_handleServerInvoke(...)
	end

	self._maid:GiveTask(self._settingRegistryServiceShared:ObserveRegisteredDefinitionsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local value = brio:GetValue()
		self:EnsureInitialized(value:GetSettingName(), value:GetDefaultValue())
	end))

	return self
end

function PlayerSettings:EnsureInitialized(settingName, defaultValue)
	assert(DataStoreStringUtils.isValidUTF8(settingName), "Bad settingName")
	assert(defaultValue ~= nil, "defaultValue cannot be nil")

	local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

	-- Paranoid UTF8 check. Don't even initialize this setting.
	if type(defaultValue) == "string" then
		assert(DataStoreStringUtils.isValidUTF8(defaultValue), "Bad UTF8 defaultValue")
	end

	if self._obj:GetAttribute(attributeName) == nil then
		local encoded = PlayerSettingsUtils.encodeForAttribute(defaultValue)

		-- Paranoid UTF8 check
		if type(encoded) == "string" then
			assert(DataStoreStringUtils.isValidUTF8(defaultValue), "Bad UTF8 defaultValue")
		end

		self._obj:SetAttribute(attributeName, encoded)
	end
end

function PlayerSettings:_handleServerInvoke(player, request, ...)
	assert(self:GetPlayer() == player, "Bad player")

	if request == PlayerSettingsConstants.REQUEST_UPDATE_SETTINGS then
		return self:_setSettings(...)
	else
		error(("Unknown request %q"):format(tostring(request)))
	end
end

function PlayerSettings:_setSettings(settingsMap)
	assert(type(settingsMap) == "table", "Bad settingsMap")

	for settingName, value in pairs(settingsMap) do
		assert(type(settingName) == "string", "Bad key")

		-- Avoid even letting these be set.
		if not DataStoreStringUtils.isValidUTF8(settingName) then
			warn("[PlayerSettings] - Bad UTF8 settingName. Skipping setting.")
			continue
		end

		local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

		if self._obj:GetAttribute(attributeName) == nil then
			warn(("[PlayerSettings] - Cannot set setting %q on attribute that is not defined on the server."):format(attributeName))
			continue
		end

		-- Paranoid UTF8 check. Avoid letting this value be set.
		if type(value) == "string" then
			if not DataStoreStringUtils.isValidUTF8(value) then
				warn(string.format("[PlayerSettings] - Bad UTF8 value setting value for %q. Skipping setting.", settingName))
				continue
			end
		end

		local decoded = PlayerSettingsUtils.decodeForNetwork(value)
		local encodedAttribute = PlayerSettingsUtils.encodeForAttribute(decoded)

		if type(encodedAttribute) == "string" then
			-- Paranoid UTF8 check. Avoid letting this value be set.
			if not DataStoreStringUtils.isValidUTF8(encodedAttribute) then
				warn(string.format("[PlayerSettings] - Bad UTF8 encodedAttribute value for %q. Skipping setting.", settingName))
				continue
			end

			-- Paranoid length check. One setting could prevent all from saving if we overflow our save limit.
			if (#encodedAttribute + #settingName) > PlayerSettingsConstants.MAX_SETTINGS_LENGTH then
				warn(string.format("[PlayerSettings] - Setting %q is too long. Skipping setting.", settingName))
				continue
			end
		end

		self._obj:SetAttribute(attributeName, encodedAttribute)
	end
end

return PlayerSettings