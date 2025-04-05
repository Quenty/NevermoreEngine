--!strict
--[=[
	@class SlottedTouchButtonUtils
]=]

local require = require(script.Parent.loader).load(script)

local _InputModeType = require("InputModeType")
local _InputKeyMapList = require("InputKeyMapList")
local _InputKeyMap = require("InputKeyMap")
local _InputTypeUtils = require("InputTypeUtils")

local SlottedTouchButtonUtils = {}

--[=[
	Internal data representing a slotted touch button
	@interface SlottedTouchButtonData
	.slotId string
	.inputModeType InputModeType
	@within SlottedTouchButtonUtils
]=]
export type SlottedTouchButtonData = {
	slotId: string,
	inputModeType: _InputModeType.InputModeType,
}

--[=[
	Touch buttons should always show up in the same position
	We use the SlotId to determine which slot we should put
	these buttons in.

	@param slotId string
	@return SlottedTouchButton
]=]
function SlottedTouchButtonUtils.createSlottedTouchButton(slotId: string): _InputTypeUtils.SlottedTouchButton
	assert(
		slotId == "primary1"
			or slotId == "primary2"
			or slotId == "primary3"
			or slotId == "primary4"
			or slotId == "primary5"
			or slotId == "inner1"
			or slotId == "inner2"
			or slotId == "jumpbutton"
			or slotId == "touchpad1",
		"Bad slotId"
	)

	return {
		type = "SlottedTouchButton",
		slotId = slotId,
	}
end

--[=[
	Returns whether an inputType is a SlottedTouchButton type

	@param inputType any
	@return boolean
]=]
function SlottedTouchButtonUtils.isSlottedTouchButton(inputType: any): boolean
	return type(inputType) == "table" and inputType.type == "SlottedTouchButton"
end

--[=[
	Gets slotted touch button data for an inputKeyMapList

	@param slotId string
	@param inputModeType InputModeType
	@return SlottedTouchButtonData
]=]
function SlottedTouchButtonUtils.createTouchButtonData(
	slotId: string,
	inputModeType: _InputModeType.InputModeType
): SlottedTouchButtonData
	return {
		slotId = slotId,
		inputModeType = inputModeType,
	}
end

--[=[
	Gets slotted touch button data for an inputKeyMapList

	@param inputKeyMapList InputKeyMapList
	@return { SlottedTouchButtonData }
]=]
function SlottedTouchButtonUtils.getSlottedTouchButtonData(inputKeyMapList: _InputKeyMapList.InputKeyMapList): { SlottedTouchButtonData }
	local slottedTouchButtons: { SlottedTouchButtonData } = {}

	for _, inputKeyMap: any in inputKeyMapList:GetInputKeyMaps() do
		for _, touchButtonData in inputKeyMap:GetInputTypesList() do
			if SlottedTouchButtonUtils.isSlottedTouchButton(touchButtonData) then
				local slottedButtonData: _InputTypeUtils.SlottedTouchButton = touchButtonData :: any
				table.insert(
					slottedTouchButtons,
					SlottedTouchButtonUtils.createTouchButtonData(
						slottedButtonData.slotId,
						inputKeyMap:GetInputModeType()
					)
				)
			end
		end
	end

	return slottedTouchButtons
end

return SlottedTouchButtonUtils
