-- Intent: Holds utilty math functions not yet available on Roblox's math library.
-- @author Quenty

local lib = {}

--- Maps a number from one range to another
-- @see http://stackoverflow.com/questions/929103/convert-a-number-range-to-another-range-maintaining-ratio
-- Make sure old range is not 0
local function MapNumber(OldValue, OldMin, OldMax, NewMin, NewMax)

	return (((OldValue - OldMin) * (NewMax - NewMin)) / (OldMax - OldMin)) + NewMin
end
lib.MapNumber = MapNumber

--- Interpolates betweeen two numbers, given an Alpha
-- @param ValueOne A number, the first one, should be less than ValueTwo
-- @param ValueTwo A number, the second one, should be greater than ValueTwo
-- @param Alpha The percent, a number in the range [0, 1], that will be used to define
--              how interpolated it is between ValueOne And ValueTwo
-- @return The lerped number. 
local function LerpNumber(ValueOne, ValueTwo, Alpha)

	return ValueOne + ((ValueTwo - ValueOne) * Alpha)
end
lib.LerpNumber = LerpNumber 

local function Round(Number, Divider)
	Divider = Divider or 1
	return (math.floor((Number/Divider)+0.5)*Divider)
end
lib.Round = Round

local function RoundUp(Number, Base)
	return math.ceil(Number/Base) * Base;
end
lib.RoundUp = RoundUp

local function RoundDown(Number, Base)
	return math.floor(Number/Base) * Base;
end
lib.RoundDown = RoundDown

return lib