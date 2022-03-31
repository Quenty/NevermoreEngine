--[=[
	@class SettingServiceBridge
]=]

local require = require(script.Parent.loader).load(script)

local ValueObject = require("ValueObject")
local Rx = require("Rx")
local ObservableSet = require("ObservableSet")

local SettingServiceBridge = {}

function SettingServiceBridge:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._settingService = ValueObject.new()
	self._settingDefinitions = ObservableSet.new()
end

function SettingServiceBridge:RegisterSettingService(settingService)
	self._settingService.Value = settingService
end

function SettingServiceBridge:RegisterDefinition(definition)
	assert(definition, "No definition")

	return self._settingDefinitions:Add(definition)
end

function SettingServiceBridge:ObserveRegisteredDefinitionsBrio()
	return self._settingDefinitions:ObserveItemsBrio()
end

function SettingServiceBridge:GetSettingsService()
	return self._settingService.Value
end

function SettingServiceBridge:ObserveSettingsService()
	return self._settingService:Observe()
end

function SettingServiceBridge:ObservePlayerSettings(player)
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

function SettingServiceBridge:PromisePlayerSettings(player)
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

function SettingServiceBridge:GetPlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	local settingService = self._settingService.Value
	if settingService then
		return settingService:GetPlayerSettings(player)
	else
		return nil
	end
end

return SettingServiceBridge