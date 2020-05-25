---
-- @module NumberToInputKeyUtils
-- @author Quenty

local NUMBERS = {
	[0] = { Enum.KeyCode.Zero; Enum.KeyCode.KeypadZero; };
	[1] = { Enum.KeyCode.One; Enum.KeyCode.KeypadOne; };
	[2] = { Enum.KeyCode.Two; Enum.KeyCode.KeypadTwo; };
	[3] = { Enum.KeyCode.Three; Enum.KeyCode.KeypadThree; };
	[4] = { Enum.KeyCode.Four; Enum.KeyCode.KeypadFour; };
	[5] = { Enum.KeyCode.Five; Enum.KeyCode.KeypadFive; };
	[6] = { Enum.KeyCode.Six; Enum.KeyCode.KeypadSix; };
	[7] = { Enum.KeyCode.Seven; Enum.KeyCode.KeypadSeven; };
	[8] = { Enum.KeyCode.Eight; Enum.KeyCode.KeypadEight; };
	[9] = { Enum.KeyCode.Nine; Enum.KeyCode.KeypadNine; };
}

local NumberToInputKeyUtils = {}

function NumberToInputKeyUtils.getInputsForNumber(number)
	return NUMBERS[number]
end

return NumberToInputKeyUtils