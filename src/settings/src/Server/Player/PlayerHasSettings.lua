--[=[
	@class PlayerHasSettings
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local SettingsBindersServer = require("SettingsBindersServer")
local PlayerDataStoreService = require("PlayerDataStoreService")
local DataStoreStringUtils = require("DataStoreStringUtils")
local PlayerSettingsConstants = require("PlayerSettingsConstants")

local PlayerHasSettings = setmetatable({}, BaseObject)
PlayerHasSettings.ClassName = "PlayerHasSettings"
PlayerHasSettings.__index = PlayerHasSettings

function PlayerHasSettings.new(player, serviceBag)
	local self = setmetatable(BaseObject.new(player), PlayerHasSettings)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._settingsBindersServer = self._serviceBag:GetService(SettingsBindersServer)
	self._playerDataStoreService = self._serviceBag:GetService(PlayerDataStoreService)

	self:_promiseLoadSettings()

	return self
end

function PlayerHasSettings:_promiseLoadSettings()
	self._settings = PlayerSettingsUtils.create(self._settingsBindersServer.PlayerSettings)
	self._maid:GiveTask(self._settings)

	self._maid:GivePromise(self._playerDataStoreService:PromiseDataStore(self._obj))
		:Then(function(dataStore)
			-- Ensure we've fully loaded before we parent.
			-- This should ensure the cache is mostly instant.

			local subStore = dataStore:GetSubStore("settings")

			return dataStore:Load("settings", {})
				:Then(function(settings)
					for settingName, value in pairs(settings) do
						local attributeName = PlayerSettingsUtils.getAttributeName(settingName)
						self._settings:SetAttribute(attributeName, PlayerSettingsUtils.encodeForAttribute(value))
					end

					self._maid:GiveTask(self._settings.AttributeChanged:Connect(function(attributeName)
						self:_handleAttributeChanged(subStore, attributeName)
					end))
				end)
		end)
		:Catch(function(err)
			warn(("[PlayerHasSettings] - Failed to load settings for player. %s"):format(tostring(err)))
		end)
		:Finally(function()
			-- Parent anyway...
			self._settings.Parent = self._obj
		end)
end

function PlayerHasSettings:_handleAttributeChanged(subStore, attributeName)
	if not PlayerSettingsUtils.isSettingAttribute(attributeName) then
		return
	end

	-- Write the new value
	local settingName = PlayerSettingsUtils.getSettingName(attributeName)
	if not DataStoreStringUtils.isValidUTF8(settingName) then
		warn(string.format("[PlayerHasSettings] - Bad settingName %q, cannot save", settingName))
		return
	end

	local newValue = PlayerSettingsUtils.decodeForAttribute(self._settings:GetAttribute(attributeName))

	if type(newValue) == "string" then
		if (#settingName + #newValue) > PlayerSettingsConstants.MAX_SETTINGS_LENGTH then
			warn(string.format("[PlayerSettingsClient.SetValue] - Setting is too long for %q. Cannot save.", settingName))
			return
		end
		-- TODO: JSON encode and check length for ther scenarios
	end

	subStore:Store(settingName, newValue)
end

return PlayerHasSettings