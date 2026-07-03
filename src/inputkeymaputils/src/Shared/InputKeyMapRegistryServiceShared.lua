--!strict
--[=[
	Provides retrieval of input key maps across the game. Available on both the client and the server.

	Input key maps are needed on the server to bind datastore settings.

	@class InputKeyMapRegistryServiceShared
]=]

local RunService = game:GetService("RunService")

local require = require(script.Parent.loader).load(script)

local Brio = require("Brio")
local InputKeyMapList = require("InputKeyMapList")
local Maid = require("Maid")
local Observable = require("Observable")
local ObservableList = require("ObservableList")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local ServiceBag = require("ServiceBag")

local InputKeyMapRegistryServiceShared = {}
InputKeyMapRegistryServiceShared.ServiceName = "InputKeyMapRegistryServiceShared"

export type InputKeyMapRegistryServiceShared = typeof(setmetatable(
	{} :: {
		_serviceBag: ServiceBag.ServiceBag,
		_maid: Maid.Maid,
		_providerLookupByName: { [string]: any },
		_providersList: ObservableList.ObservableList<any>,
	},
	{} :: typeof({ __index = InputKeyMapRegistryServiceShared })
))

function InputKeyMapRegistryServiceShared.Init(
	self: InputKeyMapRegistryServiceShared,
	serviceBag: ServiceBag.ServiceBag
): ()
	assert(not (self :: any)._serviceBag, "Already initialized")
	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._maid = Maid.new()

	self._providerLookupByName = {}

	self._providersList = ObservableList.new()
	self._maid:GiveTask(self._providersList)

	self._maid:GiveTask((self._providersList:ObserveItemsBrio() :: any):Subscribe(function(brio)
		if brio:IsDead() then
			return
		end

		local maid = brio:ToMaid()
		local provider = brio:GetValue()

		local providerName = provider:GetProviderName()

		if self._providerLookupByName[providerName] then
			error(string.format("Already have a provider with name %q", providerName))
		end

		self._providerLookupByName[providerName] = provider

		maid:GiveTask(function()
			if self._providerLookupByName[providerName] == provider then
				self._providerLookupByName[providerName] = nil
			end
		end)
	end))
end

function InputKeyMapRegistryServiceShared.RegisterProvider(
	self: InputKeyMapRegistryServiceShared,
	provider: any
): () -> ()
	assert(provider, "Bad provider")
	assert(self._providersList, "Not initialized")

	return self._providersList:Add(provider)
end

function InputKeyMapRegistryServiceShared.ObserveProvidersBrio(
	self: InputKeyMapRegistryServiceShared
): Observable.Observable<Brio.Brio<any>>
	return self._providersList:ObserveItemsBrio()
end

function InputKeyMapRegistryServiceShared.ObserveInputKeyMapListsBrio(self: InputKeyMapRegistryServiceShared): Observable.Observable<
	Brio.Brio<InputKeyMapList.InputKeyMapList>
>
	return (self:ObserveProvidersBrio() :: any):Pipe({
		RxBrioUtils.flatMapBrio(function(provider): any
			return provider:ObserveInputKeyMapListsBrio()
		end),
	})
end

function InputKeyMapRegistryServiceShared.GetProvider(self: InputKeyMapRegistryServiceShared, providerName: string): any
	assert(type(providerName) == "string", "Bad providerName")

	return self._providerLookupByName[providerName]
end

function InputKeyMapRegistryServiceShared.ObserveInputKeyMapList(
	self: InputKeyMapRegistryServiceShared,
	providerName: any,
	inputKeyMapListName: any
): Observable.Observable<
	InputKeyMapList.InputKeyMapList?
>
	assert(providerName, "Bad providerName")
	assert(inputKeyMapListName, "Bad inputKeyMapListName")

	return (Rx.combineLatest({
		providerName = providerName,
		inputKeyMapListName = inputKeyMapListName,
	}) :: any):Pipe({
		Rx.map(function(state: any): any
			if not (type(state.inputKeyMapListName) == "string" and type(state.providerName) == "string") then
				return nil
			end

			local found = self:FindInputKeyMapList(state.providerName, state.inputKeyMapListName)
			if found then
				return found
			end

			warn(
				string.format(
					"[InputKeyMapRegistryServiceShared.ObserveInputKeyMapList] - Bad inputKey name %q\n%s",
					tostring(state.providerName),
					tostring(state.inputKeyMapListName)
				)
			)

			return nil
		end),
	})
end

function InputKeyMapRegistryServiceShared.FindInputKeyMapList(
	self: InputKeyMapRegistryServiceShared,
	providerName: string,
	inputKeyMapListName: string
): InputKeyMapList.InputKeyMapList?
	assert(type(providerName) == "string", "Bad providerName")
	assert(type(inputKeyMapListName) == "string", "Bad inputKeyMapListName")

	if not RunService:IsRunning() then
		return nil
	end

	assert(self._providersList, "Not initialized")

	for _, provider in self._providerLookupByName do
		if provider:GetProviderName() == providerName then
			local found = provider:FindInputKeyMapList(inputKeyMapListName)
			if found then
				return found
			end
		end
	end

	return nil
end

function InputKeyMapRegistryServiceShared.Destroy(self: InputKeyMapRegistryServiceShared): ()
	self._maid:DoCleaning()
end

return InputKeyMapRegistryServiceShared
