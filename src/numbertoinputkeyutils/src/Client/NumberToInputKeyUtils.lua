--!strict
--[=[
	Maps a number to a set of inputs. Useful for shortcut codes in menus.
	@class NumberToInputKeyUtils
]=]

local NUMBERS = {
	[0] = { Enum.KeyCode.Zero, Enum.KeyCode.KeypadZero },
	[1] = { Enum.KeyCode.One, Enum.KeyCode.KeypadOne },
	[2] = { Enum.KeyCode.Two, Enum.KeyCode.KeypadTwo },
	[3] = { Enum.KeyCode.Three, Enum.KeyCode.KeypadThree },
	[4] = { Enum.KeyCode.Four, Enum.KeyCode.KeypadFour },
	[5] = { Enum.KeyCode.Five, Enum.KeyCode.KeypadFive },
	[6] = { Enum.KeyCode.Six, Enum.KeyCode.KeypadSix },
	[7] = { Enum.KeyCode.Seven, Enum.KeyCode.KeypadSeven },
	[8] = { Enum.KeyCode.Eight, Enum.KeyCode.KeypadEight },
	[9] = { Enum.KeyCode.Nine, Enum.KeyCode.KeypadNine },
}

local KEYCODES_TO_NUMBER = {}
local ALL_KEYCODES = {}

for number, keyCodes in NUMBERS do
	for _, keyCode in keyCodes do
		KEYCODES_TO_NUMBER[keyCode] = number
		table.insert(ALL_KEYCODES, keyCode)
	end
end

local NumberToInputKeyUtils = {}

--[=[
	Retrieves inputs for a given number.
	@param number number
	@return { Enum.KeyCode }
]=]
function NumberToInputKeyUtils.getInputsForNumber(number: number): { Enum.KeyCode }?
	assert(type(number) == "number", "Bad number")

	return NUMBERS[number]
end

--[=[
	Retrieves number from keyCode
	@param keyCode KeyCode
	@return number
]=]
function NumberToInputKeyUtils.getNumberFromKeyCode(keyCode: Enum.KeyCode): number?
	assert(keyCode, "Bad keyCode")

	return KEYCODES_TO_NUMBER[keyCode]
end

--[=[
	Returns all number keycodes

	@return { Enum.KeyCode }
]=]
function NumberToInputKeyUtils.getAllNumberKeyCodes(): { Enum.KeyCode }
	return ALL_KEYCODES
end

return NumberToInputKeyUtils
