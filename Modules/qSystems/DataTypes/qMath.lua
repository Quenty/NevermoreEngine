local lib = {}

-- qMath.lua
-- @author Quenty

local function MapNumber(OldValue, OldMin, OldMax, NewMin, NewMax)
	-- Maps a number from one range to another
	-- http://stackoverflow.com/questions/929103/convert-a-number-range-to-another-range-maintaining-ratio
	-- Make sure old range is not 0

	return (((OldValue - OldMin) * (NewMax - NewMin)) / (OldMax - OldMin)) + NewMin
end
lib.MapNumber = MapNumber

local function ClampNumber(Number, Lower, Upper)
	if Number > Upper then
		return Upper, true
	elseif Number < Lower then
		return Lower, true
	else
		return Number, false
	end
end
lib.ClampNumber = ClampNumber;
lib.clampNumber = ClampNumber;


local function RoundUp(Number, Base)
	return math.ceil(Number/Base) * Base;
end
lib.RoundUp = RoundUp
lib.roundUp = RoundUp

local function RoundDown(Number, Base)
	return math.floor(Number/Base) * Base;
end
lib.RoundDown = RoundDown
lib.roundDown = RoundDown

local function RoundNumber(number, divider)
	--verifyArg(number, "number", "number")
	--verifyArg(divider, "number", "divider", true)

	divider = divider or 1
	return (math.floor((number/divider)+0.5)*divider)
end
lib.roundNumber = RoundNumber
lib.RoundNumber = RoundNumber
lib.round_number = RoundNumber


local function Sign(Number)
	if Number == 0 then
		return 0
	else
		return Number / math.abs(Number) 
	end
end
lib.Sign = Sign
lib.sign = Sign


local function Vector2ToCartisian(Vector2ToConvert, ScreenMiddle)
	--return Vector2.new(Vector2ToConvert.x - ScreenMiddle.x, ScreenMiddle.y - Vector2ToConvert.y)
	return Vector2ToConvert - ScreenMiddle
end
lib.Vector2ToCartisian = Vector2ToCartisian
lib.vector2ToCartisian = Vector2ToCartisian


local function Cartisian2ToVector(CartisianToConvert, ScreenMiddle)
	--return Vector2.new(CartisianToConvert.x + ScreenMiddle.x, ScreenMiddle.y - CartisianToConvert.y)
	return CartisianToConvert + ScreenMiddle
end
lib.Cartisian2ToVector = Cartisian2ToVector 
lib.cartisian2ToVector = Cartisian2ToVector


local function InvertCartisian2(CartisianVector2)
	-- Insert's a CartisianVector2 value.
	
	return -CartisianVector2
end
lib.InvertCartisian2 =InvertCartisian2
lib.invertCartisian2 =InvertCartisian2

local function LerpNumber(ValueOne, ValueTwo, Alpha)
	--- Interpolates betweeen two numbers, given an Alpha
	-- @param ValueOne A number, the first one, should be less than ValueTwo
	-- @param ValueTwo A number, the second one, should be greater than ValueTwo
	-- @param Alpha The percent, a number in the range [0, 1], that will be used to define
	--              how interpolated it is between ValueOne And ValueTwo
	-- @return The lerped number. 

	return ValueOne + ((ValueTwo - ValueOne) * Alpha)
end
lib.LerpNumber = LerpNumber 
lib.lerpNumber = LerpNumber

return lib