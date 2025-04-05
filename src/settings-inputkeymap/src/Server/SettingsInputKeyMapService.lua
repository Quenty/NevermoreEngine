--[=[
	@class SettingsInputKeyMapService
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local InputKeyMapSetting = require("InputKeyMapSetting")
local _ServiceBag = require("ServiceBag")

local SettingsInputKeyMapService = {}
SettingsInputKeyMapService.ServiceName = "SettingsInputKeyMapService"

function SettingsInputKeyMapService:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("SettingsService"))
	self._inputKeyMapRegistry = self._serviceBag:GetService(require("InputKeyMapRegistryServiceShared"))

end

function SettingsInputKeyMapService:Start()
	self._maid:GiveTask(self._inputKeyMapRegistry:ObserveInputKeyMapListsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local inputKeyMapList = brio:GetValue()

		maid:GiveTask(InputKeyMapSetting.new(self._serviceBag, inputKeyMapList))
	end))
end

function SettingsInputKeyMapService:Destroy()
	self._maid:DoCleaning()
end

return SettingsInputKeyMapService