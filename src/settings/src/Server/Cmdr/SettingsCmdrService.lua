--[=[
	Provides commands involving player settings

	@class SettingsCmdrService
]=]

local require = require(script.Parent.loader).load(script)

local PlayerUtils = require("PlayerUtils")
local SettingsCmdrUtils = require("SettingsCmdrUtils")
local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local SettingsCmdrService = {}
SettingsCmdrService.ServiceName = "SettingsCmdrService"

function SettingsCmdrService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._cmdrService = self._serviceBag:GetService(require("CmdrService"))
	self._settingService = self._serviceBag:GetService(require("SettingsService"))
end

function SettingsCmdrService:Start()
	self:_setupCommands()
end

function SettingsCmdrService:_setupCommands()
	self._maid:GivePromise(self._cmdrService:PromiseCmdr()):Then(function(cmdr)
		SettingsCmdrUtils.registerSettingDefinition(cmdr, self._serviceBag)
	end)

	self._cmdrService:RegisterCommand({
		Name = "restore-setting",
		Aliases = {},
		Description = "Restores the player setting to default.",
		Group = "Settings",
		Args = {
			{
				Name = "Players",
				Type = "players",
				Description = "Players to restore the default settings to.",
			},
			{
				Name = "Settings",
				Type = "settingDefinitions",
				Description = "Settings to restore.",
			},
		},
	}, function(_context, players, settingsDefinitions)
		local givenTo = {}

		for _, player in players do
			local playerSettings = self._settingService:PromisePlayerSettings(player):Wait()
			for _, settingDefinition in settingsDefinitions do
				playerSettings:RestoreDefault(settingDefinition:GetSettingName(), settingDefinition:GetDefaultValue())
			end
			table.insert(givenTo, PlayerUtils.formatName(player))
		end

		return string.format("Reset settings for %s", table.concat(givenTo, ", "))
	end)
end

function SettingsCmdrService:Destroy()
	self._maid:DoCleaning()
end

return SettingsCmdrService
