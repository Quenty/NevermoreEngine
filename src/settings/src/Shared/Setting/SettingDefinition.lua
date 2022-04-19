--[=[
	@class SettingDefinition
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local SettingProperty = require("SettingProperty")
local SettingServiceBridge = require("SettingServiceBridge")
local ServiceBag = require("ServiceBag")

local SettingDefinition = {}
SettingDefinition.ClassName = "SettingDefinition"
SettingDefinition.__index = SettingDefinition

--[=[
	Constructs a new setting definition which defines the name and the defaultValue

	@param settingName string
	@param defaultValue T
	@return SettingDefinition<T>
]=]
function SettingDefinition.new(settingName, defaultValue)
	local self = setmetatable({}, SettingDefinition)

	assert(type(settingName) == "string", "Bad settingName")
	assert(defaultValue ~= nil, "DefaultValue cannot be nil")

	self._settingName = settingName
	self._defaultValue = defaultValue

	return self
end

--[=[
	Gets a new setting property for the given definition

	@param serviceBag ServiceBag
	@param player Player
	@return SettingProperty<T>
]=]
function SettingDefinition:GetSettingProperty(serviceBag, player)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Bad player")

	return SettingProperty.new(serviceBag, player, self)
end

--[=[
	Gets a new setting property for the given definition

	@param serviceBag ServiceBag
	@return SettingProperty<T>
]=]
function SettingDefinition:GetLocalPlayerSettingProperty(serviceBag)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	return self:GetSettingProperty(serviceBag, Players.LocalPlayer)
end

--[=[
	Retrieves the default name of the setting
	@return string
]=]
function SettingDefinition:GetSettingName()
	return self._settingName
end

--[=[
	Retrieves the default value for the setting
	@return T
]=]
function SettingDefinition:GetDefaultValue()
	return self._defaultValue
end

--[=[
	Optional registration to the service bag. If registered, ensures all existing
	players and all new players get this setting defined. This may be necessary for
	replication.

	@param serviceBag ServiceBag.
]=]
function SettingDefinition:Init(serviceBag)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	-- not strictly necessary... but...

	serviceBag:GetService(SettingServiceBridge):RegisterDefinition(self)
end

--[=[
	Optional registration to the service bag
]=]
function SettingDefinition:RegisterToService(serviceBag)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	local settingServiceBridge = serviceBag:GetService(SettingServiceBridge)

	if serviceBag:IsStarted() and not serviceBag:HasService(self) then
		-- We've already started so let's ensure
		settingServiceBridge:RegisterDefinition(self)
	else
		settingServiceBridge:RegisterDefinition(serviceBag:GetService(self))
	end
end


return SettingDefinition