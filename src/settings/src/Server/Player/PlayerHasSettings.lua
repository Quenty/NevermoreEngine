--[=[
	@class PlayerHasSettings
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local SettingsBindersServer = require("SettingsBindersServer")
local PlayerDataStoreService = require("PlayerDataStoreService")

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
						self._settings:SetAttribute(attributeName, value)
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
	local newValue = self._settings:GetAttribute(attributeName)
	subStore:Store(settingName, newValue)
end

return PlayerHasSettings