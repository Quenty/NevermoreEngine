--[=[
	@class SettingsCmdrUtils
]=]

local require = require(script.Parent.loader).load(script)

local ServiceBag = require("ServiceBag")
local SettingsDataService = require("SettingsDataService")

local SettingsCmdrUtils = {}

function SettingsCmdrUtils.registerSettingDefinition(cmdr, serviceBag)
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	local settingsDataService = serviceBag:GetService(SettingsDataService)

	local settingDefinitionType = {
		Transform = function(text)
			local definitions = settingsDataService:GetSettingDefinitions()
			local settingNames = {}
		for _, settingDefinition in definitions do
			table.insert(settingNames, settingDefinition:GetSettingName())
		end

		local find = cmdr.Util.MakeFuzzyFinder(settingNames)
		return find(text)
		end;
		Validate = function(keys)
		return #keys > 0, "No item model with that name could be found."
		end,
		Autocomplete = function(keys)
		return keys
		end,
		Parse = function(keys)
		local name = keys[1]

		local definitions = settingsDataService:GetSettingDefinitions()
			for _, settingDefinition in definitions do
				if settingDefinition:GetSettingName() == name then
					return settingDefinition
				end
			end

			return nil
		end;
	}

	cmdr.Registry:RegisterType("settingDefinition", settingDefinitionType)
	cmdr.Registry:RegisterType("settingDefinitions", cmdr.Util.MakeListableType(settingDefinitionType))
end


return SettingsCmdrUtils