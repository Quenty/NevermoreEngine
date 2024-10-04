--[=[
	Registers the settings automatically so we can validate on the server.
	@class InputKeyMapSetting
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local InputKeyMapSettingUtils = require("InputKeyMapSettingUtils")
local InputKeyMapSettingConstants = require("InputKeyMapSettingConstants")
local SettingDefinition = require("SettingDefinition")
local SettingsDataService = require("SettingsDataService")

local InputKeyMapSetting = setmetatable({}, BaseObject)
InputKeyMapSetting.ClassName = "InputKeyMapSetting"
InputKeyMapSetting.__index = InputKeyMapSetting

function InputKeyMapSetting.new(serviceBag, inputKeyMapList)
	local self = setmetatable(BaseObject.new(), InputKeyMapSetting)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._settingDataService = self._serviceBag:GetService(SettingsDataService)

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

		maid:GiveTask(self._settingDataService:RegisterSettingDefinition(definition))
	end))

	return self
end

return InputKeyMapSetting