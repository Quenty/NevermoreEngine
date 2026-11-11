--!strict
--[=[
	Registers the settings automatically so we can validate on the server.
	@class InputKeyMapSetting
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local InputKeyMapList = require("InputKeyMapList")
local InputKeyMapSettingConstants = require("InputKeyMapSettingConstants")
local InputKeyMapSettingUtils = require("InputKeyMapSettingUtils")
local ServiceBag = require("ServiceBag")
local SettingDefinition = require("SettingDefinition")
local SettingsDataService = require("SettingsDataService")

local InputKeyMapSetting = setmetatable({}, BaseObject)
InputKeyMapSetting.ClassName = "InputKeyMapSetting"
InputKeyMapSetting.__index = InputKeyMapSetting

export type InputKeyMapSetting =
	typeof(setmetatable(
		{} :: {
			_serviceBag: ServiceBag.ServiceBag,
			_settingDataService: SettingsDataService.SettingsDataService,
			_inputKeyMapList: InputKeyMapList.InputKeyMapList,
		},
		{} :: typeof({ __index = InputKeyMapSetting })
	))
	& BaseObject.BaseObject

function InputKeyMapSetting.new(
	serviceBag: ServiceBag.ServiceBag,
	inputKeyMapList: InputKeyMapList.InputKeyMapList
): InputKeyMapSetting
	local self: InputKeyMapSetting = setmetatable(BaseObject.new() :: any, InputKeyMapSetting)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._settingDataService = self._serviceBag:GetService(SettingsDataService) :: any

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
