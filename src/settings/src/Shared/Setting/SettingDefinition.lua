--[=[
	These settings definitions are used to define a setting and register them on both the client and server. See
	[SettingDefinitionProvider] for more details on grouping these.

	Notably a setting is basically anything on the client that can be stored on the server by the client, and that
	relatively minimal validation is required upon. This can be both user-set settings, as well as very temporary
	data.

	```lua
	local SettingDefinition = require("SettingDefinition")

	return require("SettingDefinitionProvider").new({
		LastTimeUpdateSeen = 0;
		LastTimeShopSeen = 0;
	})
	```

	@class SettingDefinition
]=]

local require = require(script.Parent.loader).load(script)

local Players = game:GetService("Players")

local SettingsDataService = require("SettingsDataService")
local SettingProperty = require("SettingProperty")
local ServiceBag = require("ServiceBag")
local DuckTypeUtils = require("DuckTypeUtils")
local Maid = require("Maid")
local _ServiceBag = require("ServiceBag")

local SettingDefinition = {}
SettingDefinition.ClassName = "SettingDefinition"
SettingDefinition.ServiceName = "SettingDefinition"
SettingDefinition.__index = SettingDefinition

--[=[
	Constructs a new setting definition which defines the name and the defaultValue

	@param settingName string
	@param defaultValue T
	@return SettingDefinition<T>
]=]
function SettingDefinition.new(settingName, defaultValue)
	assert(type(settingName) == "string", "Bad settingName")
	assert(defaultValue ~= nil, "DefaultValue cannot be nil")

	local self = setmetatable({}, SettingDefinition)

	self._settingName = settingName
	self._defaultValue = defaultValue

	self.ServiceName = self._settingName .. "SettingDefinition"

	return self
end

--[=[
	Initializes the setting definition from a service bag.

	@param serviceBag ServiceBag
]=]
function SettingDefinition:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(serviceBag, "No serviceBag")
	assert(not self._maid, "Already initialized")

	self._maid = Maid.new()
	self._serviceBag = assert(serviceBag, "No serviceBag")

	local settingsDataService = self._serviceBag:GetService(SettingsDataService)
	self._maid:GiveTask(settingsDataService:RegisterSettingDefinition(self))
end

--[=[
	Gets the value for the given player

	@param player Player
	@return T
]=]
function SettingDefinition:Get(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player") or player == nil, "Bad player")
	assert(self._serviceBag, "Retrieve from serviceBag")

	return self:GetSettingProperty(self._serviceBag, player):GetValue()
end

--[=[
	Sets the value

	@param player Player
	@param value T
]=]
function SettingDefinition:Set(player: Player, value)
	assert(typeof(player) == "Instance" and player:IsA("Player") or player == nil, "Bad player")
	assert(self._serviceBag, "Retrieve from serviceBag")

	return self:GetSettingProperty(self._serviceBag, player):SetValue(value)
end

--[=[
	Promise gets the value

	@param player Player
	@return Promise<T>
]=]
function SettingDefinition:Promise(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player") or player == nil, "Bad player")
	assert(self._serviceBag, "Retrieve from serviceBag")

	return self:GetSettingProperty(self._serviceBag, player):PromiseValue()
end

--[=[
	Promise gets the value

	@param player Player
	@param value T
	@return Promise<T>
]=]
function SettingDefinition:PromiseSet(player: Player, value)
	assert(typeof(player) == "Instance" and player:IsA("Player") or player == nil, "Bad player")
	assert(self._serviceBag, "Retrieve from serviceBag")

	return self:GetSettingProperty(self._serviceBag, player):PromiseSetValue(value)
end

--[=[
	Promise gets the value

	@param player Player
	@return Promise<T>
]=]
function SettingDefinition:Observe(player: Player)
	assert(typeof(player) == "Instance" and player:IsA("Player") or player == nil, "Bad player")
	assert(self._serviceBag, "Retrieve from serviceBag")

	return self:GetSettingProperty(self._serviceBag, player):Observe()
end

--[=[
	Returns true if the value is a setting definition

	@param value any
	@return boolean
]=]
function SettingDefinition.isSettingDefinition(value: any): boolean
	return DuckTypeUtils.isImplementation(SettingDefinition, value)
end

--[=[
	Gets a new setting property for the given definition

	@param serviceBag ServiceBag
	@param player Player
	@return SettingProperty<T>
]=]
function SettingDefinition:GetSettingProperty(serviceBag, player: Player)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")
	assert(typeof(player) == "Instance" and player:IsA("Player") or player == nil, "Bad player")

	player = player or Players.LocalPlayer

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
function SettingDefinition:GetSettingName(): string
	return self._settingName
end

--[=[
	Retrieves the default value for the setting
	@return T
]=]
function SettingDefinition:GetDefaultValue()
	return self._defaultValue
end

function SettingDefinition:Destroy()
	self._maid:DoCleaning()
end

return SettingDefinition