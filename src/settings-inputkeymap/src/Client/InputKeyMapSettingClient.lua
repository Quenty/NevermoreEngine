--[=[
	@class InputKeyMapSettingClient
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local InputKeyMapSettingUtils = require("InputKeyMapSettingUtils")
local SettingsServiceClient = require("SettingsServiceClient")
local InputKeyMapSettingConstants = require("InputKeyMapSettingConstants")

local InputKeyMapSettingClient = setmetatable({}, BaseObject)
InputKeyMapSettingClient.ClassName = "InputKeyMapSettingClient"
InputKeyMapSettingClient.__index = InputKeyMapSettingClient

function InputKeyMapSettingClient.new(serviceBag, inputKeyMapList)
	local self = setmetatable(BaseObject.new(), InputKeyMapSettingClient)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._settingService = self._serviceBag:GetService(SettingsServiceClient)

	self._inputKeyMapList = assert(inputKeyMapList, "No inputKeyMapList")

	self._maid:GiveTask(self._settingService:ObserveLocalPlayerSettingsBrio():Subscribe(function(settingsBrio)
		if settingsBrio:IsDead() then
			return
		end

		local settingMaid = settingsBrio:ToMaid()
		local settings = settingsBrio:GetValue()

		settingMaid:GiveTask(self._inputKeyMapList:ObservePairsBrio():Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local maid = brio:ToMaid()
			local inputModeType, inputKeyMap = brio:GetValue()

			local settingName = InputKeyMapSettingUtils.getSettingName(inputKeyMapList, inputModeType)
			local settingProperty = settings:GetSettingProperty(settingName, InputKeyMapSettingConstants.DEFAULT_VALUE)

			-- Try to retrieve
			maid:GiveTask(settingProperty:Observe():Subscribe(function(currentValue)
				if currentValue == InputKeyMapSettingConstants.DEFAULT_VALUE or currentValue == nil then
					inputKeyMap:RestoreDefault()
				elseif type(currentValue) == "string" and currentValue ~= InputKeyMapSettingConstants.DEFAULT_VALUE then
					local decoded = InputKeyMapSettingUtils.decodeInputTypeList(currentValue)
					if decoded then
						inputKeyMap:SetInputTypesList(decoded)
					else
						warn(("[InputKeyMapSettingClient] - Failed to decode setting value from %q"):format(tostring(currentValue)))
					end
				else
					warn(("[InputKeyMapSettingClient] - Failed to decode setting value from %q"):format(tostring(currentValue)))
				end
			end))

			maid:GiveTask(inputKeyMap:ObserveInputTypesList():Subscribe(function(inputTypeList)
				-- Store
				local encoded = InputKeyMapSettingUtils.encodeInputTypeList(inputTypeList)
				if encoded ~= InputKeyMapSettingUtils.encodeInputTypeList(inputKeyMap:GetDefaultInputTypesList()) then
					settings:SetValue(settingName, encoded)
				else
					settings:SetValue(settingName, InputKeyMapSettingConstants.DEFAULT_VALUE)
				end
			end))
		end))
	end))

	return self
end

return InputKeyMapSettingClient