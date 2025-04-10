--[=[
	@class PlayerHasSettings
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local PlayerSettings = require("PlayerSettings")
local PlayerDataStoreService = require("PlayerDataStoreService")
local DataStoreStringUtils = require("DataStoreStringUtils")
local PlayerSettingsConstants = require("PlayerSettingsConstants")
local PlayerBinder = require("PlayerBinder")

local PlayerHasSettings = setmetatable({}, BaseObject)
PlayerHasSettings.ClassName = "PlayerHasSettings"
PlayerHasSettings.__index = PlayerHasSettings

export type PlayerHasSettings = typeof(setmetatable(
	{} :: {
		_serviceBag: any,
		_playerSettingsBinder: PlayerSettings.PlayerSettings,
		_playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService,
	},
	{} :: typeof({ __index = PlayerHasSettings })
)) & BaseObject.BaseObject

function PlayerHasSettings.new(player: Player, serviceBag)
	local self = setmetatable(BaseObject.new(player), PlayerHasSettings)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._playerSettingsBinder = self._serviceBag:GetService(PlayerSettings)
	self._playerDataStoreService = self._serviceBag:GetService(PlayerDataStoreService)

	self:_promiseLoadSettings()

	return self
end

function PlayerHasSettings:_promiseLoadSettings()
	self._settings = self._maid:Add(PlayerSettingsUtils.create())

	self._maid:GivePromise(self._playerDataStoreService:PromiseDataStore(self._obj))
		:Then(function(dataStore)
			-- Ensure we've fully loaded before we parent.
			-- This should ensure the cache is mostly instant.

			local subStore = dataStore:GetSubStore("settings")

			return dataStore:Load("settings", {})
				:Then(function(settings)
					for settingName, value in settings do
						local attributeName = PlayerSettingsUtils.getAttributeName(settingName)
						self._settings:SetAttribute(attributeName, PlayerSettingsUtils.encodeForAttribute(value))
					end

					self._maid:GiveTask(self._settings.AttributeChanged:Connect(function(attributeName)
						self:_handleAttributeChanged(subStore, attributeName)
					end))
				end)
		end)
		:Catch(function(err)
			warn(string.format("[PlayerHasSettings] - Failed to load settings for player. %s", tostring(err)))
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

return PlayerBinder.new("PlayerHasSettings", PlayerHasSettings)