--[=[
	@class SettingsInputKeyMapServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local InputKeyMapSettingClient = require("InputKeyMapSettingClient")
local _ServiceBag = require("ServiceBag")

local SettingsInputKeyMapServiceClient = {}
SettingsInputKeyMapServiceClient.ServiceName = "SettingsInputKeyMapServiceClient"

function SettingsInputKeyMapServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("SettingsServiceClient"))
	self._serviceBag:GetService(require("InputModeServiceClient"))
	self._serviceBag:GetService(require("InputKeyMapServiceClient"))
	self._inputKeyMapRegistry = self._serviceBag:GetService(require("InputKeyMapRegistryServiceShared"))
end

function SettingsInputKeyMapServiceClient:Start()
	self._maid:GiveTask(self._inputKeyMapRegistry:ObserveInputKeyMapListsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid, inputKeyMapList = brio:ToMaidAndValue()

		maid:GiveTask(InputKeyMapSettingClient.new(self._serviceBag, inputKeyMapList))
	end))
end

function SettingsInputKeyMapServiceClient:Destroy()
	self._maid:DoCleaning()
end

return SettingsInputKeyMapServiceClient