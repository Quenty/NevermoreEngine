--[=[
	Provides retrieval of input key maps across the game. Available on both the client and the server.

	Input key maps are needed on the server to bind datastore settings.

	@class InputKeyMapRegistryServiceShared
]=]

local RunService = game:GetService("RunService")

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local ObservableList = require("ObservableList")
local RxBrioUtils = require("RxBrioUtils")

local InputKeyMapRegistryServiceShared = {}
InputKeyMapRegistryServiceShared.ServiceName = "InputKeyMapRegistryServiceShared"

function InputKeyMapRegistryServiceShared:Init(serviceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._providerLookupByName = {}

	self._providersList = ObservableList.new()
	self._maid:GiveTask(self._providersList)

	self._maid:GiveTask(self._providersList:ObserveItemsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local provider = brio:GetValue()

		local providerName = provider:GetProviderName()

		if self._providerLookupByName[providerName] then
			error(("Already have a provider with name %q"):format(providerName))
		end

		self._providerLookupByName[providerName] = provider

		maid:GiveTask(function()
			if self._providerLookupByName[providerName] == provider then
				self._providerLookupByName[providerName] = nil
			end
		end)
	end))
end

function InputKeyMapRegistryServiceShared:RegisterProvider(provider)
	assert(provider, "Bad provider")
	assert(self._providersList, "Not initialized")

	return self._providersList:Add(provider)
end

function InputKeyMapRegistryServiceShared:ObserveProvidersBrio()
	return self._providersList:ObserveItemsBrio()
end

function InputKeyMapRegistryServiceShared:ObserveInputKeyMapListsBrio()
	return self:ObserveProvidersBrio():Pipe({
		RxBrioUtils.flatMapBrio(function(provider)
			return provider:ObserveInputKeyMapListsBrio()
		end)
	})
end

function InputKeyMapRegistryServiceShared:GetProvider(providerName)
	assert(type(providerName) == "string", "Bad providerName")

	return self._providerLookupByName[providerName]
end

-- function InputKeyMapRegistryServiceShared:ObserveInputKeyMapList(providerName, inputKeyMapListName)
-- 	assert(type(providerName) == "string", "Bad providerName")
-- 	assert(type(inputKeyMapListName) == "string", "Bad inputKeyMapListName")

-- end

function InputKeyMapRegistryServiceShared:FindInputKeyMapList(providerName, inputKeyMapListName)
	assert(type(providerName) == "string", "Bad providerName")
	assert(type(inputKeyMapListName) == "string", "Bad inputKeyMapListName")

	if not RunService:IsRunning() then
		return nil
	end

	assert(self._providersList, "Not initialized")

	for _, provider in pairs(self._providerLookupByName) do
		if provider:GetProviderName() == providerName then
			local found = provider:FindInputKeyMapList(inputKeyMapListName)
			if found then
				return found
			end
		end
	end

	return nil
end

function InputKeyMapRegistryServiceShared:Destroy()
	self._maid:DoCleaning()
end


return InputKeyMapRegistryServiceShared