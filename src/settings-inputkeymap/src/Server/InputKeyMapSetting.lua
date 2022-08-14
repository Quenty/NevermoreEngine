--[=[
	Registers the settings automatically so we can validate on the server.
	@class InputKeyMapSetting
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local InputKeyMapSettingUtils = require("InputKeyMapSettingUtils")
local SettingsService = require("SettingsService")
local InputKeyMapSettingConstants = require("InputKeyMapSettingConstants")
local SettingDefinition = require("SettingDefinition")
local SettingRegistryServiceShared = require("SettingRegistryServiceShared")

local InputKeyMapSetting = setmetatable({}, BaseObject)
InputKeyMapSetting.ClassName = "InputKeyMapSetting"
InputKeyMapSetting.__index = InputKeyMapSetting

function InputKeyMapSetting.new(serviceBag, inputKeyMapList)
	local self = setmetatable(BaseObject.new(), InputKeyMapSetting)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._settingService = self._serviceBag:GetService(SettingsService)
	self._settingRegistryServiceShared = self._serviceBag:GetService(SettingRegistryServiceShared)

	self._inputKeyMapList = assert(inputKeyMapList, "No inputKeyMapList")

	self._maid:GiveTask(self._inputKeyMapList:ObservePairsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		-- Register settings
		local maid = brio:ToMaid()
		local inputModeType, _ = brio:GetValue()

		local settingName = InputKeyMapSettingUtils.getSettingName(inputKeyMapList, inputModeType)
		local definition = SettingDefinition.new(settingName, InputKeyMapSettingConstants.DEFAULT_VALUE)

		maid:GiveTask(self._settingRegistryServiceShared:RegisterSettingDefinition(definition))
	end))

	return self
end

return InputKeyMapSetting