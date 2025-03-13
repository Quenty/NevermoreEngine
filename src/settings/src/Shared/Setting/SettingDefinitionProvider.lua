--[=[
	Provides settings in bulk, and can be initialized by a [ServiceBag]. See [SettingDefinition] for
	more details on how to use this.

	:::tip
	These settings providers should be used on both the client and the server. On the client, these
	are registered with the [SettingsDataService] so that they can be shown in UI automatically
	if desired.

	On the server, these are registered with [SettingsDataService] and then are checked before
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

local Maid = require("Maid")
local SettingDefinition = require("SettingDefinition")
local _ServiceBag = require("ServiceBag")

local SettingDefinitionProvider = {}
SettingDefinitionProvider.ClassName = "SettingDefinitionProvider"
SettingDefinitionProvider.ServiceName = "SettingDefinitionProvider"
SettingDefinitionProvider.__index = SettingDefinitionProvider

--[=[
	Constructs a new provider with a list of [SettingDefinition]'s.

	```lua
	-- In one location
	local SettingDefinition = require("SettingDefinition")

	return require("SettingDefinitionProvider").new({
		KeyBinding = Enum.KeyCode.X;
		CameraShake = true;
		CameraSensitivity = 1;
	})
	```

	Usage:

	```lua
	local ourSettings = serviceBag:GetService(require("OurSettings"))

	print(ourSettings.CameraShake:Get(Players.LocalPlayer), true)

	ourSettings.CameraShake:Set(Players.LocalPlayer, false)

	ourSettings.CameraShake:Promise(Players.LocalPlayer)
		:Then(function(cameraShake)
			print(cameraShake)
		end)
	```

	@param settingDefinitions { SettingDefinition }
	@return SettingDefinitionProvider
]=]
function SettingDefinitionProvider.new(settingDefinitions)
	local self = setmetatable({}, SettingDefinitionProvider)

	self._settingDefinitionList = {}
	self._lookup = {}

	for key, value in settingDefinitions do
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

	table.insert(self._settingDefinitionList, settingDefinition)
	self._lookup[settingDefinition:GetSettingName()] = settingDefinition
end

--[=[
	Initializes the provider, storing the data in [SettingsDataService]

	@param serviceBag ServiceBag
]=]
function SettingDefinitionProvider:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(serviceBag, "No serviceBag")
	assert(not self._maid, "Already initialized")

	self._maid = Maid.new()
	self._serviceBag = assert(serviceBag, "No serviceBag")

	self._initializedDefinitionLookup = {}

	-- Register our setting definitions
	for _, settingDefinition in self._settingDefinitionList do
		local initialized = self._serviceBag:GetService(settingDefinition)
		self._initializedDefinitionLookup[settingDefinition] = initialized

		-- Store lookup to overcome metatable lookup
		self[settingDefinition:GetSettingName()] = initialized
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
	if self._serviceBag then
		local copy = table.clone(self._settingDefinitionList)

		for key, settingDefinition in copy do
			copy[key] = assert(self._initializedDefinitionLookup[settingDefinition], "Missing settingDefinition")
		end

		return copy
	end

	return table.clone(self._settingDefinitionList)
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
	elseif index == "_lookup"
		or index == "_settingDefinitionList"
		or index == "_maid"
		or index == "_initializedDefinitionLookup"
		or index == "_serviceBag" then

		return rawget(self, index)
	elseif type(index) == "string" then
		local lookup = rawget(self, "_lookup")
		local settingDefinition = lookup[index]
		if not settingDefinition then
			error(string.format("Bad index %q into SettingDefinitionProvider", tostring(index)))
		end

		if self._serviceBag then
			return assert(self._initializedDefinitionLookup[settingDefinition], "Missing settingDefinition")
		else
			return settingDefinition
		end
	else
		error(string.format("Bad index %q into SettingDefinitionProvider", tostring(index)))
	end
end

--[=[
	Gets a new setting definition if it exists

	@param settingName string
	@return SettingDefinition
]=]
function SettingDefinitionProvider:Get(settingName: string)
	assert(type(settingName) == "string", "Bad settingName")

	local found = self._lookup[settingName]
	if not found then
		return nil
	end

	if self._serviceBag then
		return assert(self._initializedDefinitionLookup[found], "Missing settingDefinition")
	else
		return found
	end
end

--[=[
	Cleans up the setting registration
]=]
function SettingDefinitionProvider:Destroy()
	self._maid:DoCleaning()
end

return SettingDefinitionProvider