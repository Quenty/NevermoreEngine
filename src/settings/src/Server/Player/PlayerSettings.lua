--[=[
	@class PlayerSettings
]=]

local require = require(script.Parent.loader).load(script)

local PlayerSettingsBase = require("PlayerSettingsBase")
local PlayerSettingsConstants = require("PlayerSettingsConstants")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local SettingServiceBridge = require("SettingServiceBridge")

local PlayerSettings = setmetatable({}, PlayerSettingsBase)
PlayerSettings.ClassName = "PlayerSettings"
PlayerSettings.__index = PlayerSettings

function PlayerSettings.new(obj, serviceBag)
	local self = setmetatable(PlayerSettingsBase.new(obj, serviceBag), PlayerSettings)

	self._bridge = self._serviceBag:GetService(SettingServiceBridge)

	self._remoteFunction = Instance.new("RemoteFunction")
	self._remoteFunction.Name = PlayerSettingsConstants.REMOTE_FUNCTION_NAME
	self._remoteFunction.Parent = self._obj
	self._maid:GiveTask(self._remoteFunction)

	self._remoteFunction.OnServerInvoke = function(...)
		return self:_handleServerInvoke(...)
	end

	self._maid:GiveTask(self._bridge:ObserveRegisteredDefinitionsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local value = brio:GetValue()
		self:EnsureInitialized(value:GetSettingName(), value:GetDefaultValue())
	end))

	return self
end

function PlayerSettings:EnsureInitialized(settingName, defaultValue)
	assert(defaultValue ~= nil, "defaultValue cannot be nil")

	local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

	if self._obj:GetAttribute(attributeName) == nil then
		self._obj:SetAttribute(attributeName, defaultValue)
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

		local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

		if self._obj:GetAttribute(attributeName) == nil then
			warn("[PlayerSettings] - Cannot set setting on attribute that is not defined on the server")
			continue
		end

		local decoded = PlayerSettingsUtils.decodeForNetwork(value)
		self._obj:SetAttribute(attributeName, decoded)
	end
end

return PlayerSettings