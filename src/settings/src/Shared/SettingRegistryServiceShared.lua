--[=[
	Shared between client and server, letting us centralize definitions in one place.

	@class SettingRegistryServiceShared
]=]

local require = require(script.Parent.loader).load(script)

local ValueObject = require("ValueObject")
local Rx = require("Rx")
local ObservableSet = require("ObservableSet")
local Maid = require("Maid")

local SettingRegistryServiceShared = {}

--[=[
	Initializes the shared registry service. Should be done via [ServiceBag].

	@param serviceBag ServiceBag
]=]
function SettingRegistryServiceShared:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._settingService = ValueObject.new()
	self._maid:GiveTask(self._settingService)

	self._settingDefinitions = ObservableSet.new()
	self._maid:GiveTask(self._settingDefinitions)
end

function SettingRegistryServiceShared:GetSettingDefinitions()
	return self._settingDefinitions:GetList()
end

--[=[
	Registers the shared setting service for this bridge

	@param settingService SettingService
]=]
function SettingRegistryServiceShared:RegisterSettingService(settingService)
	self._settingService.Value = settingService
end

--[=[
	Registers settings definitions

	@param definition SettingDefinition
	@return callback -- Cleanup callback
]=]
function SettingRegistryServiceShared:RegisterSettingDefinition(definition)
	assert(definition, "No definition")

	return self._settingDefinitions:Add(definition)
end

--[=[
	Observes the registered definitions

	@return Observable<Brio<SettingDefinition>>
]=]
function SettingRegistryServiceShared:ObserveRegisteredDefinitionsBrio()
	return self._settingDefinitions:ObserveItemsBrio()
end

--[=[
	Gets the current settings service

	@return SettingService
]=]
function SettingRegistryServiceShared:GetSettingsService()
	return self._settingService.Value
end

--[=[
	Observes the current settings service

	@return Observable<SettingService>
]=]
function SettingRegistryServiceShared:ObserveSettingsService()
	return self._settingService:Observe()
end

--[=[
	Observes the player's settings

	@param player Player
	@return Observable<PlayerSettingsBase>
]=]
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

--[=[
	Promises the player's settings

	@param player Player
	@return Promise<PlayerSettingsBase>
]=]
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

--[=[
	Gets the player's settings

	@param player Player
	@return Promise<PlayerSettingsBase>
]=]
function SettingRegistryServiceShared:GetPlayerSettings(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	local settingService = self._settingService.Value
	if settingService then
		return settingService:GetPlayerSettings(player)
	else
		return nil
	end
end

--[=[
	Cleans up the shared registry service
]=]
function SettingRegistryServiceShared:Destroy()
	self._maid:DoCleaning()
end

return SettingRegistryServiceShared