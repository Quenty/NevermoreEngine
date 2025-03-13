--[=[
	@class InputKeyMapServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local Maid = require("Maid")
local PseudoLocalize = require("PseudoLocalize")
local _ServiceBag = require("ServiceBag")

local InputKeyMapServiceClient = {}
InputKeyMapServiceClient.ServiceName = "InputKeyMapServiceClient"

function InputKeyMapServiceClient:Init(serviceBag: _ServiceBag.ServiceBag)
	assert(not self._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("InputModeServiceClient"))

	-- Internal
	self._translator = self._serviceBag:GetService(require("InputKeyMapTranslator"))
	self._registryService = self._serviceBag:GetService(require("InputKeyMapRegistryServiceShared"))

	self:_ensureLocalizationEntries()
end

function InputKeyMapServiceClient:FindInputKeyMapList(providerName, listName)
	return self._registryService:FindInputKeyMapList(providerName, listName)
end

function InputKeyMapServiceClient:_ensureLocalizationEntries()
	self._maid:GiveTask(self._registryService:ObserveInputKeyMapListsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local inputKeyMapList = brio:GetValue()

		local text = inputKeyMapList:GetBindingName()

		local localizationTable = self._translator:GetLocalizationTable()
		local key = inputKeyMapList:GetBindingTranslationKey()
		local source = text
		local context = string.format("InputKeyMapServiceClient.%s", inputKeyMapList:GetListName())
		local localeId = "en"
		local value = text

		localizationTable:SetEntryValue(key, source, context, localeId, value)
		localizationTable:SetEntryValue(key, source, context,
			PseudoLocalize.getDefaultPseudoLocaleId(),
			PseudoLocalize.pseudoLocalize(value))
	end))
end

function InputKeyMapServiceClient:Destroy()
	self._maid:DoCleaning()
end

return InputKeyMapServiceClient