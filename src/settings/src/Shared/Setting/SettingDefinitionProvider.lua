--[=[
	@class SettingDefinitionProvider
]=]

local require = require(script.Parent.loader).load(script)

local SettingRegistryServiceShared = require("SettingRegistryServiceShared")
local Maid = require("Maid")

local SettingDefinitionProvider = {}
SettingDefinitionProvider.ClassName = "SettingDefinitionProvider"
SettingDefinitionProvider.ServiceName = "SettingDefinitionProvider"
SettingDefinitionProvider.__index = SettingDefinitionProvider

function SettingDefinitionProvider.new(settingDefinitions)
	local self = setmetatable({}, SettingDefinitionProvider)

	self._settingDefinitions = {}
	self._lookup = {}

	for _, settingDefinition in pairs(settingDefinitions) do
		table.insert(self._settingDefinitions, settingDefinition)
		self._lookup[settingDefinition:GetSettingName()] = settingDefinition
	end

	return self
end

function SettingDefinitionProvider:Init(serviceBag)
	assert(serviceBag, "No serviceBag")
	assert(not self._maid, "Already initialized")

	self._maid = Maid.new()

	local settingRegistryServiceShared = serviceBag:GetService(SettingRegistryServiceShared)
	for _, settingDefinition in pairs(self._settingDefinitions) do
		self._maid:GiveTask(settingRegistryServiceShared:RegisterSettingDefinition(settingDefinition))
	end
end

function SettingDefinitionProvider:Start()
	-- Empty, to prevent us from erroring on service bag init
end

function SettingDefinitionProvider:GetSettingDefinitions()
	return self._settingDefinitions
end

function SettingDefinitionProvider:__index(index)
	if SettingDefinitionProvider[index] then
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

function SettingDefinitionProvider:Get(settingName)
	return self._lookup[settingName]
end

function SettingDefinitionProvider:Destroy()
	self._maid:DoCleaning()
end

return SettingDefinitionProvider