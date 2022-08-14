--[=[
	Shared between client and server, letting us centralize definitions in one place.

	@class SettingRegistryServiceShared
]=]

local require = require(script.Parent.loader).load(script)

local ValueObject = require("ValueObject")
local Rx = require("Rx")
local ObservableSet = require("ObservableSet")

local SettingRegistryServiceShared = {}

function SettingRegistryServiceShared:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._settingService = ValueObject.new()
	self._settingDefinitions = ObservableSet.new()
end

function SettingRegistryServiceShared:RegisterSettingService(settingService)
	self._settingService.Value = settingService
end

function SettingRegistryServiceShared:RegisterSettingDefinition(definition)
	assert(definition, "No definition")

	return self._settingDefinitions:Add(definition)
end

function SettingRegistryServiceShared:ObserveRegisteredDefinitionsBrio()
	return self._settingDefinitions:ObserveItemsBrio()
end

function SettingRegistryServiceShared:GetSettingsService()
	return self._settingService.Value
end

function SettingRegistryServiceShared:ObserveSettingsService()
	return self._settingService:Observe()
end

function SettingRegistryServiceShared:ObservePlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return self:ObserveSettingsService():Pipe({
		Rx.switchMap(function(settingService)
			if settingService then
				return settingService:ObservePlayerSettings(player)
			else
				return Rx.of(nil)
			end
		end)
	})
end

function SettingRegistryServiceShared:PromisePlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return Rx.toPromise(self._settingService:Observe():Pipe({
			Rx.where(function(x)
				return x ~= nil
			end)
		}))
		:Then(function(settingService)
			return settingService:PromisePlayerSettings(player)
		end)
end

function SettingRegistryServiceShared:GetPlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	local settingService = self._settingService.Value
	if settingService then
		return settingService:GetPlayerSettings(player)
	else
		return nil
	end
end

return SettingRegistryServiceShared