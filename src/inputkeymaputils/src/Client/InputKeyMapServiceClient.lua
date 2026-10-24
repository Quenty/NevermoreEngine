--!strict
--[=[
	@class InputKeyMapServiceClient
]=]

local require = require(script.Parent.loader).load(script)

local InputKeyMapList = require("InputKeyMapList")
local InputKeyMapRegistryServiceShared = require("InputKeyMapRegistryServiceShared")
local Maid = require("Maid")
local ServiceBag = require("ServiceBag")

local InputKeyMapServiceClient = {}
InputKeyMapServiceClient.ServiceName = "InputKeyMapServiceClient"

export type InputKeyMapServiceClient = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_translator: any,
		_registryService: InputKeyMapRegistryServiceShared.InputKeyMapRegistryServiceShared,
	},
	{} :: typeof({ __index = InputKeyMapServiceClient })
))

function InputKeyMapServiceClient.Init(self: InputKeyMapServiceClient, serviceBag: ServiceBag.ServiceBag): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	-- External
	self._serviceBag:GetService(require("InputModeServiceClient"))

	-- Internal
	self._translator = self._serviceBag:GetService(require("InputKeyMapTranslator"))
	self._registryService = self._serviceBag:GetService(require("InputKeyMapRegistryServiceShared")) :: any

	self:_ensureLocalizationEntries()
end

function InputKeyMapServiceClient.FindInputKeyMapList(
	self: InputKeyMapServiceClient,
	providerName: string,
	listName: string
): InputKeyMapList.InputKeyMapList?
	return self._registryService:FindInputKeyMapList(providerName, listName)
end

function InputKeyMapServiceClient._ensureLocalizationEntries(self: InputKeyMapServiceClient): ()
	self._maid:GiveTask(self._registryService:ObserveInputKeyMapListsBrio():Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local inputKeyMapList = brio:GetValue()

		local text = inputKeyMapList:GetBindingName()

		local key = inputKeyMapList:GetBindingTranslationKey()
		local context = string.format("InputKeyMapServiceClient.%s", inputKeyMapList:GetListName())

		-- Batched with the translator's other writes
		self._translator:SetEntryValue(key, text, context, "en", text)
	end))
end

function InputKeyMapServiceClient.Destroy(self: InputKeyMapServiceClient): ()
	self._maid:DoCleaning()
end

return InputKeyMapServiceClient
