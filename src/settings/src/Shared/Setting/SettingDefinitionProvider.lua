--[=[
	Provides settings in bulk, and can be initialized by a [ServiceBag]. See [SettingDefinition] for
	more details on how to use this.

	:::tip
	These settings providers should be used on both the client and the server. On the client, these
	are registered with the [SettingRegistryServiceShared] so that they can be shown in UI automatically
	if desired.

	On the server, these are registered with [SettingRegistryServiceShared] and then are checked before
	arbitrary data can e sent.
	:::

	```lua
	local SettingDefinition = require("SettingDefinition")

	return require("SettingDefinitionProvider").new({
		KeyBinding = Enum.KeyCode.X;
		CameraShake = true;
		CameraSensitivity = 1;
	})
	```

	@class SettingDefinitionProvider
]=]

local require = require(script.Parent.loader).load(script)

local SettingRegistryServiceShared = require("SettingRegistryServiceShared")
local Maid = require("Maid")
local SettingDefinition = require("SettingDefinition")

local SettingDefinitionProvider = {}
SettingDefinitionProvider.ClassName = "SettingDefinitionProvider"
SettingDefinitionProvider.ServiceName = "SettingDefinitionProvider"
SettingDefinitionProvider.__index = SettingDefinitionProvider

--[=[
	Constructs a new provider with a list of [SettingDefinition]'s.

	```lua
	local SettingDefinition = require("SettingDefinition")

	return require("SettingDefinitionProvider").new({
		KeyBinding = Enum.KeyCode.X;
		CameraShake = true;
		CameraSensitivity = 1;
	})
	```

	@param settingDefinitions { SettingDefinition }
	@return SettingDefinitionProvider
]=]
function SettingDefinitionProvider.new(settingDefinitions)
	local self = setmetatable({}, SettingDefinitionProvider)

	self._settingDefinitions = {}
	self._lookup = {}

	for key, value in pairs(settingDefinitions) do
		if type(key) == "number" then
			assert(SettingDefinition.isSettingDefinition(key), "Bad settingDefinition")

			self:_addSettingDefinition(key)
		elseif type(key) == "string" then
			if SettingDefinition.isSettingDefinition(value) then
				self:_addSettingDefinition(value)
			else
				local definition = SettingDefinition.new(key, value)
				self:_addSettingDefinition(definition)
			end
		else
			error("Bad key for settingDefinitions")
		end
	end

	return self
end

function SettingDefinitionProvider:_addSettingDefinition(settingDefinition)
	assert(SettingDefinition.isSettingDefinition(settingDefinition), "Bad settingDefinition")

	table.insert(self._settingDefinitions, settingDefinition)
	self._lookup[settingDefinition:GetSettingName()] = settingDefinition
end

--[=[
	Initializes the provider, storing the data in [SettingRegistryServiceShared]

	@param serviceBag ServiceBag
]=]
function SettingDefinitionProvider:Init(serviceBag)
	assert(serviceBag, "No serviceBag")
	assert(not self._maid, "Already initialized")

	self._maid = Maid.new()

	local settingRegistryServiceShared = serviceBag:GetService(SettingRegistryServiceShared)
	for _, settingDefinition in pairs(self._settingDefinitions) do
		self._maid:GiveTask(settingRegistryServiceShared:RegisterSettingDefinition(settingDefinition))
	end
end

--[=[
	Starts the provider. Empty.
]=]
function SettingDefinitionProvider:Start()
	-- Empty, to prevent us from erroring on service bag init
end

--[=[
	Returns the setting definition

	@return { SettingDefinition }
]=]
function SettingDefinitionProvider:GetSettingDefinitions()
	return self._settingDefinitions
end

--[=[
	You can index the provider to get a setting. For example

	```lua
	local SettingDefinition = require("SettingDefinition")

	local provider = require("SettingDefinitionProvider").new({
		KeyBinding = Enum.KeyCode.X;
		CameraShake = true;
		CameraSensitivity = 1;
	})

	local service = serviceBag:GetService(provider)

	-- Write a setting
	service.CamaraShake:GetLocalPlayerSettingProperty(serviceBag).Value = false
	```

	@param index string
	@return SettingDefinition
]=]
function SettingDefinitionProvider:__index(index)
	if index == nil then
		error("[SettingDefinitionProvider] - Cannot index provider with nil value")
	elseif SettingDefinitionProvider[index] then
		return SettingDefinitionProvider[index]
	elseif index == "_lookup" or index == "_settingDefinitions" or index == "_maid" then
		return rawget(self, index)
	elseif type(index) == "string" then
		local lookup = rawget(self, "_lookup")
		local settingDefinition = lookup[index]
		if not settingDefinition then
			error(("Bad index %q into SettingDefinitionProvider"):format(tostring(index)))
		else
			return settingDefinition
		end
	else
		error(("Bad index %q into SettingDefinitionProvider"):format(tostring(index)))
	end
end

--[=[
	Gets a new setting definition if it exists

	@param settingName string
	@return SettingDefinition
]=]
function SettingDefinitionProvider:Get(settingName)
	assert(type(settingName) == "string", "Bad settingName")

	return self._lookup[settingName]
end

--[=[
	Cleans up the setting registration
]=]
function SettingDefinitionProvider:Destroy()
	self._maid:DoCleaning()
end

return SettingDefinitionProvider