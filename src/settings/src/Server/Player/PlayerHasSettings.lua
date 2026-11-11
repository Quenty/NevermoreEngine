--!strict
--[=[
	@class PlayerHasSettings
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local DataStoreStringUtils = require("DataStoreStringUtils")
local PlayerBinder = require("PlayerBinder")
local PlayerDataStoreService = require("PlayerDataStoreService")
local PlayerSettings = require("PlayerSettings")
local PlayerSettingsConstants = require("PlayerSettingsConstants")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local ServiceBag = require("ServiceBag")

local PlayerHasSettings = setmetatable({}, BaseObject)
PlayerHasSettings.ClassName = "PlayerHasSettings"
PlayerHasSettings.__index = PlayerHasSettings

export type PlayerHasSettings =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_playerSettingsBinder: any,
			_playerDataStoreService: PlayerDataStoreService.PlayerDataStoreService,
			_settings: Folder?,
		},
		{} :: typeof({ __index = PlayerHasSettings })
	))
	& BaseObject.BaseObject

function PlayerHasSettings.new(player: Player, serviceBag: ServiceBag.ServiceBag): PlayerHasSettings
	local self: PlayerHasSettings = setmetatable(BaseObject.new(player) :: any, PlayerHasSettings)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._playerSettingsBinder = self._serviceBag:GetService(PlayerSettings)
	self._playerDataStoreService = self._serviceBag:GetService(PlayerDataStoreService) :: any

	self:_promiseLoadSettings()

	return self
end

function PlayerHasSettings._promiseLoadSettings(self: PlayerHasSettings): ()
	self._settings = PlayerSettingsUtils.create()
	self._maid:GiveTask(function()
		if self._settings then
			self._settings:Destroy()
		end
		self._settings = nil
	end)

	local loadPromise = self._maid:GivePromise(self._playerDataStoreService:PromiseDataStore(self._obj :: Player));
	(loadPromise :: any)
		:Then(function(dataStore)
			-- Ensure we've fully loaded before we parent.
			-- This should ensure the cache is mostly instant.

			local subStore = dataStore:GetSubStore("settings")

			return dataStore:Load("settings", {}):Then(function(settings)
				if not self._settings then
					return
				end

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
			if self._settings then
				-- Parent anyway...
				self._settings.Parent = self._obj
			end
		end)
end

function PlayerHasSettings._handleAttributeChanged(self: PlayerHasSettings, subStore: any, attributeName: string): ()
	if not PlayerSettingsUtils.isSettingAttribute(attributeName) then
		return
	end

	if not self._settings then
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
			warn(
				string.format("[PlayerSettingsClient.SetValue] - Setting is too long for %q. Cannot save.", settingName)
			)
			return
		end
		-- TODO: JSON encode and check length for ther scenarios
	end

	subStore:Store(settingName, newValue)
end

return PlayerBinder.new("PlayerHasSettings", PlayerHasSettings :: any) :: PlayerBinder.PlayerBinder<PlayerHasSettings>
