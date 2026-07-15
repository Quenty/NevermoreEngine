--!strict
--[=[
	@class PlayerSettings
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")
local Brio = require("Brio")
local DataStoreStringUtils = require("DataStoreStringUtils")
local Maid = require("Maid")
local Observable = require("Observable")
local PlayerSettingsBase = require("PlayerSettingsBase")
local PlayerSettingsConstants = require("PlayerSettingsConstants")
local PlayerSettingsInterface = require("PlayerSettingsInterface")
local PlayerSettingsUtils = require("PlayerSettingsUtils")
local Remoting = require("Remoting")
local ServiceBag = require("ServiceBag")
local SettingsDataService = require("SettingsDataService")

local PlayerSettings = {}
PlayerSettings.ClassName = "PlayerSettings"
PlayerSettings.__index = PlayerSettings
-- Runtime inheritance only. Typing the metatable target as `any` keeps the old solver from
-- chasing the full PlayerSettingsBase type here, which otherwise overflows its complexity
-- budget ("Code is too complex"). The inherited surface is supplied structurally below.
setmetatable(PlayerSettings :: any, PlayerSettingsBase)

-- Minimal structural surface of SettingsDataService that this class actually uses. Embedding
-- the full SettingsDataService metatable type blows up the old solver, so we type only what
-- we call here.
type SettingsDataServiceLike = {
	ObserveRegisteredDefinitionsBrio: (self: SettingsDataServiceLike) -> Observable.Observable<Brio.Brio<any>>,
}

-- Only the dynamic remoting member this class touches.
type RemotingLike = {
	RequestUpdateSettings: any,
}

-- Minimal structural surface inherited from PlayerSettingsBase that this class uses. See the
-- setmetatable note above for why we don't intersect PlayerSettingsBase.PlayerSettingsBase.
type PlayerSettingsBaseLike = {
	_obj: Folder,
	_maid: Maid.Maid,
	GetPlayer: (self: any) -> Player?,
}

export type PlayerSettings =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_remoting: RemotingLike,
			_settingsDataService: SettingsDataServiceLike,
		},
		{} :: typeof({ __index = PlayerSettings })
	))
	& PlayerSettingsBaseLike

export type SettingsMap = { [string]: any }

function PlayerSettings.new(folder: Folder, serviceBag: ServiceBag.ServiceBag): PlayerSettings
	local self: PlayerSettings = setmetatable(PlayerSettingsBase.new(folder, serviceBag) :: any, PlayerSettings)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._settingsDataService = self._serviceBag:GetService(SettingsDataService) :: any

	self:_setupRemoting()

	self._maid:GiveTask(self._settingsDataService:ObserveRegisteredDefinitionsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local value = brio:GetValue()
		self:EnsureInitialized(value:GetSettingName(), value:GetDefaultValue())
	end))

	self._maid:GiveTask((PlayerSettingsInterface :: any).Server:Implement(self._obj, self))

	return self
end

function PlayerSettings.EnsureInitialized<T>(self: PlayerSettings, settingName: string, defaultValue: T): ()
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
			assert(DataStoreStringUtils.isValidUTF8(encoded), "Bad UTF8 defaultValue")
		end

		self._obj:SetAttribute(attributeName, encoded)
	end
end

function PlayerSettings._setupRemoting(self: PlayerSettings): ()
	self._remoting = self._maid:Add(Remoting.new(self._obj, "PlayerSettings", Remoting.Realms.SERVER)) :: any

	self._maid:Add(self._remoting.RequestUpdateSettings:Bind(function(player: Player, settingsMap: SettingsMap)
		assert(self:GetPlayer() == player, "Bad player")

		return self:_setSettingsMap(settingsMap)
	end))
end

function PlayerSettings._setSettingsMap(self: PlayerSettings, settingsMap: SettingsMap): ()
	assert(type(settingsMap) == "table", "Bad settingsMap")

	for settingName, value in settingsMap do
		assert(type(settingName) == "string", "Bad key")

		-- Avoid even letting these be set.
		if not DataStoreStringUtils.isValidUTF8(settingName) then
			warn(`[PlayerSettings] - Bad UTF8 settingName. Skipping setting.`)
			continue
		end

		local attributeName = PlayerSettingsUtils.getAttributeName(settingName)

		if self._obj:GetAttribute(attributeName) == nil then
			warn(
				`[PlayerSettings] - Cannot set setting {attributeName} on attribute that is not defined on the server. Be sure to initialize settings on both server + client.`
			)
			continue
		end

		-- Paranoid UTF8 check. Avoid letting this value be set.
		if type(value) == "string" then
			if not DataStoreStringUtils.isValidUTF8(value) then
				warn(`[PlayerSettings] - Bad UTF8 value setting value for {settingName}. Skipping setting.`)
				continue
			end
		end

		local decoded = PlayerSettingsUtils.decodeForNetwork(value)
		local encodedAttribute = PlayerSettingsUtils.encodeForAttribute(decoded)

		if type(encodedAttribute) == "string" then
			-- Paranoid UTF8 check. Avoid letting this value be set.
			if not DataStoreStringUtils.isValidUTF8(encodedAttribute) then
				warn(
					string.format(
						"[PlayerSettings] - Bad UTF8 encodedAttribute value for %q. Skipping setting.",
						settingName
					)
				)
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

return Binder.new("PlayerSettings", PlayerSettings :: any) :: Binder.Binder<PlayerSettings>
