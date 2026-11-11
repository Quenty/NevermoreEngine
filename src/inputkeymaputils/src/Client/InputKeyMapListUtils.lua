--!strict
--[=[
	Client side utility helpers for observing input modes for the current client.

	@class InputKeyMapListUtils
]=]

local require = require(script.Parent.loader).load(script)

local InputKeyMap = require("InputKeyMap")
local InputKeyMapList = require("InputKeyMapList")
local InputModeType = require("InputModeType")
local InputModeTypeSelector = require("InputModeTypeSelector")
local InputTypeUtils = require("InputTypeUtils")
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
function InputKeyMapListUtils.getNewInputModeTypeSelector(
	inputKeyMapList: InputKeyMapList.InputKeyMapList,
	serviceBag: ServiceBag.ServiceBag
): InputModeTypeSelector.InputModeTypeSelector
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
function InputKeyMapListUtils.observeActiveInputKeyMap(
	inputKeyMapList: InputKeyMapList.InputKeyMapList,
	serviceBag: ServiceBag.ServiceBag
): Observable.Observable<InputKeyMap.InputKeyMap?>
	assert(InputKeyMapList.isInputKeyMapList(inputKeyMapList), "Bad inputKeyMapList")
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	return (InputKeyMapListUtils.observeActiveInputModeType(inputKeyMapList, serviceBag) :: any):Pipe({
		Rx.switchMap(function(activeInputModeType): any
			if activeInputModeType then
				return inputKeyMapList:ObserveInputKeyMapForInputMode(activeInputModeType)
			else
				return Rx.of(nil)
			end
		end),
	}) :: any
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
function InputKeyMapListUtils.observeActiveInputTypesList(
	inputKeyMapList: InputKeyMapList.InputKeyMapList,
	serviceBag: ServiceBag.ServiceBag
): Observable.Observable<{ InputTypeUtils.InputType }?>
	assert(InputKeyMapList.isInputKeyMapList(inputKeyMapList), "Bad inputKeyMapList")
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	return (InputKeyMapListUtils.observeActiveInputKeyMap(inputKeyMapList, serviceBag) :: any):Pipe({
		Rx.switchMap(function(activeInputMap): any
			if activeInputMap then
				return activeInputMap:ObserveInputTypesList()
			else
				return Rx.of(nil)
			end
		end) :: any,
		Rx.distinct() :: any,
	}) :: any
end

--[=[
	Observes the active input mode currently selected.

	@param inputKeyMapList InputKeyMapList
	@param serviceBag ServiceBag
	@return Observable<InputModeType?>
]=]
function InputKeyMapListUtils.observeActiveInputModeType(
	inputKeyMapList: InputKeyMapList.InputKeyMapList,
	serviceBag: ServiceBag.ServiceBag
): Observable.Observable<InputModeType.InputModeType?>
	assert(InputKeyMapList.isInputKeyMapList(inputKeyMapList), "Bad inputKeyMapList")
	assert(ServiceBag.isServiceBag(serviceBag), "Bad serviceBag")

	return Observable.new((function(sub: any)
		local maid = Maid.new()

		local selector = maid:Add(InputKeyMapListUtils.getNewInputModeTypeSelector(inputKeyMapList, serviceBag))

		maid:GiveTask(selector.Changed:Connect(function()
			sub:Fire(selector.Value)
		end))
		sub:Fire(selector.Value)

		return maid
	end) :: any) :: any
end

return InputKeyMapListUtils
