--!strict
--[=[
	@class SettingsInputKeyMapService
]=]

local require = require(script.Parent.loader).load(script)

local InputKeyMapSetting = require("InputKeyMapSetting")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local SettingsInputKeyMapService = {}
SettingsInputKeyMapService.ServiceName = "SettingsInputKeyMapService"

export type SettingsInputKeyMapService = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_inputKeyMapRegistry: any,
	},
	{} :: typeof({ __index = SettingsInputKeyMapService })
))

function SettingsInputKeyMapService.Init(self: SettingsInputKeyMapService, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("SettingsService"))
	self._inputKeyMapRegistry = self._serviceBag:GetService(require("InputKeyMapRegistryServiceShared"))
end

function SettingsInputKeyMapService.Start(self: SettingsInputKeyMapService): ()
	self._maid:GiveTask(self._inputKeyMapRegistry:ObserveInputKeyMapListsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local inputKeyMapList = brio:GetValue()

		maid:GiveTask(InputKeyMapSetting.new(self._serviceBag, inputKeyMapList))
	end))
end

function SettingsInputKeyMapService.Destroy(self: SettingsInputKeyMapService): ()
	self._maid:DoCleaning()
end

return SettingsInputKeyMapService
