--[=[
	Client side utility helpers for observing input modes for the current client.

	@class InputKeyMapListUtils
]=]

local require = require(script.Parent.loader).load(script)

local InputKeyMapList = require("InputKeyMapList")
local InputModeTypeSelector = require("InputModeTypeSelector")
local Maid = require("Maid")
local Observable = require("Observable")
local Rx = require("Rx")
local ServiceBag = require("ServiceBag")

local InputKeyMapListUtils = {}

--[=[
	Observes the input enums list

	@param inputKeyMapList InputKeyMapList
	@param serviceBag ServiceBag
	@return InputModeTypeSelector
]=]
function InputKeyMapListUtils.getNewInputModeTypeSelector(inputKeyMapList, serviceBag)
	assert(InputKeyMapList.isInputKeyMapList(inputKeyMapList), "Bad inputKeyMapList")
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	return InputModeTypeSelector.fromObservableBrio(serviceBag, inputKeyMapList:ObserveInputModesTypesBrio())
end

--[=[
	Observes the input types for the active input map

	@param inputKeyMapList InputKeyMapList
	@param serviceBag ServiceBag
	@return Observable<InputKeyMap>
]=]
function InputKeyMapListUtils.observeActiveInputKeyMap(inputKeyMapList, serviceBag)
	assert(InputKeyMapList.isInputKeyMapList(inputKeyMapList), "Bad inputKeyMapList")
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	return InputKeyMapListUtils.observeActiveInputModeType(inputKeyMapList, serviceBag):Pipe({
		Rx.switchMap(function(activeInputModeType)
			if activeInputModeType then
				return inputKeyMapList:ObserveInputKeyMapForInputMode(activeInputModeType)
			else
				return Rx.of(nil)
			end
		end);
	})
end

--[=[
	Observes the input types for the active input map.

	:::warning
	This should be used for hinting inputs, but it's preferred to
	bind inputs for all modes. See [InputKeyMapList.ObserveInputEnumsList]
	:::

	@param inputKeyMapList InputKeyMapList
	@param serviceBag ServiceBag
	@return Observable<{ InputType }?>
]=]
function InputKeyMapListUtils.observeActiveInputTypesList(inputKeyMapList, serviceBag)
	assert(InputKeyMapList.isInputKeyMapList(inputKeyMapList), "Bad inputKeyMapList")
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	return InputKeyMapListUtils.observeActiveInputKeyMap(inputKeyMapList, serviceBag):Pipe({
		Rx.switchMap(function(activeInputMap)
			if activeInputMap then
				return activeInputMap:ObserveInputTypesList()
			else
				return Rx.of(nil)
			end
		end);
		Rx.distinct();
	})
end

--[=[
	Observes the active input mode currently selected.

	@param inputKeyMapList InputKeyMapList
	@param serviceBag ServiceBag
	@return Observable<InputModeType?>
]=]
function InputKeyMapListUtils.observeActiveInputModeType(inputKeyMapList, serviceBag)
	assert(InputKeyMapList.isInputKeyMapList(inputKeyMapList), "Bad inputKeyMapList")
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	return Observable.new(function(sub)
		local maid = Maid.new()

		local selector = maid:Add(InputKeyMapListUtils.getNewInputModeTypeSelector(inputKeyMapList, serviceBag))

		maid:GiveTask(selector.Changed:Connect(function()
			sub:Fire(selector.Value)
		end))
		sub:Fire(selector.Value)

		return maid
	end)
end

return InputKeyMapListUtils