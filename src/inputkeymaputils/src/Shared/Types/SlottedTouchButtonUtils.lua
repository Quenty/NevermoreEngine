--[=[
	@class SlottedTouchButtonUtils
]=]

local require = require(script.Parent.loader).load(script)

local InputModeType = require("InputModeType")

local SlottedTouchButtonUtils = {}

--[=[
	Internal data representing a slotted touch button
	@interface SlottedTouchButtonData
	.slotId string
	.inputModeType InputModeType
	@within SlottedTouchButtonUtils
]=]


--[=[
	A touch button that goes into a specific slot. This ensures
	consistent slot positions.

	@interface SlottedTouchButton
	.type "SlottedTouchButton"
	.slotId string
	@within SlottedTouchButtonUtils
]=]

--[=[
	Touch buttons should always show up in the same position
	We use the SlotId to determine which slot we should put
	these buttons in.

	@param slotId string
	@return SlottedTouchButton
]=]
function SlottedTouchButtonUtils.createSlottedTouchButton(slotId)
	assert(slotId == "primary1"
		or slotId == "primary2"
		or slotId == "primary3"
		or slotId == "primary4"
		or slotId == "primary5"
		or slotId == "inner1"
		or slotId == "inner2"
		or slotId == "jumpbutton"
		or slotId == "touchpad1", "Bad slotId")

	return {
		type = "SlottedTouchButton";
		slotId = slotId;
	}
end

--[=[
	Returns whether an inputType is a SlottedTouchButton type

	@param inputType any
	@return boolean
]=]
function SlottedTouchButtonUtils.isSlottedTouchButton(inputType)
	return type(inputType) == "table" and inputType.type == "SlottedTouchButton"
end

--[=[
	Gets slotted touch button data for an inputKeyMapList

	@param slotId string
	@param inputModeType InputModeType
	@return SlottedTouchButtonData
]=]
function SlottedTouchButtonUtils.createTouchButtonData(slotId, inputModeType)
	return {
		slotId = slotId;
		inputModeType = inputModeType;
	}
end

--[=[
	Gets slotted touch button data for an inputKeyMapList

	@param inputKeyMapList InputKeyMapList
	@return { SlottedTouchButtonData }
]=]
function SlottedTouchButtonUtils.getSlottedTouchButtonData(inputKeyMapList)
	local slottedTouchButtons = {}

	for _, inputKeyMap in pairs(inputKeyMapList) do
		assert(InputModeType.isInputModeType(inputKeyMap.inputModeType), "Bad inputKeyMap.inputModeType")
		assert(inputKeyMap.inputTypes, "Bad inputKeyMap.inputTypes")

		for _, touchButtonData in pairs(inputKeyMap.inputTypes) do
			if SlottedTouchButtonUtils.isSlottedTouchButton(touchButtonData) then
				table.insert(slottedTouchButtons, SlottedTouchButtonUtils.createTouchButtonData(
					touchButtonData.slotId, inputKeyMap.inputModeType))
			end
		end
	end

	return slottedTouchButtons
end

return SlottedTouchButtonUtils
