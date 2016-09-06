-- @author Quenty

local lib = setmetatable({}, {__index = math})

local ceil = math.ceil
local floor = math.floor
local unpack = unpack or table.unpack
local abs = math.abs

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

local function RoundUp(...)
	--- Ceils all parameters by the last parameter, which is the place
	
	local tuple = {...}
	local numTuple = #tuple - 1

	if numTuple > 0 then
		local place = tuple[numTuple + 1]
		for a = 1, numTuple do
			tuple[a] = ceil(tuple[a]/place) * place
		end
		return unpack(tuple, 1, numTuple)
	else
		return ceil(tuple[1])
	end
end
lib.RoundUp = RoundUp
lib.roundUp = RoundUp
lib.ceil = RoundUp

local function RoundDown(...)
	--- Floors all parameters by the last parameter, which is the place
	
	local tuple = {...}
	local numTuple = #tuple - 1

	if numTuple > 0 then
		local place = tuple[numTuple + 1]
		for a = 1, numTuple do
			tuple[a] = floor(tuple[a]/place) * place
		end
		return unpack(tuple, 1, numTuple)
	else
		return floor(tuple[1])
	end
end
lib.RoundDown = RoundDown
lib.roundDown = RoundDown
lib.floor = RoundDown

local function RoundNumber(...)
	--- Rounds all parameters by the last parameter, which is the place
	
	local tuple = {...}
	local numTuple = #tuple - 1

	if numTuple > 0 then
		local place = tuple[numTuple + 1]
		for a = 1, numTuple do
			tuple[a] = floor(tuple[a]/place + .5) * place
		end
		return unpack(tuple, 1, numTuple)
	else
		return floor(tuple[1] + .5)
	end
end
lib.round = RoundNumber
lib.Round = RoundNumber
lib.roundNumber = RoundNumber
lib.RoundNumber = RoundNumber
lib.round_number = RoundNumber

local function Sign(n)
	return n == 0 and 0 or n / abs(n)
end
lib.Sign = Sign
lib.sign = Sign

local function Vector2ToCartisian(Vector2ToConvert, ScreenMiddle)
	--return Vector2.new(Vector2ToConvert.x - ScreenMiddle.x, ScreenMiddle.y - Vector2ToConvert.y)
	return Vector2ToConvert - ScreenMiddle
end
lib.Vector2ToCartisian = Vector2ToCartisian
lib.vector2ToCartisian = Vector2ToCartisian


local function Cartisian2ToVector(CartisianToConvert, ScreenMiddle) -- Please remove when possible
	-- Adds 2 params together

	--return Vector2.new(CartisianToConvert.x + ScreenMiddle.x, ScreenMiddle.y - CartisianToConvert.y)
	return CartisianToConvert + ScreenMiddle
end
lib.Cartisian2ToVector = Cartisian2ToVector -- Please remove when possible
lib.cartisian2ToVector = Cartisian2ToVector -- Please remove when possible


local function InvertCartisian2(CartisianVector2) -- Please remove when possible
	-- Invert's a CartisianVector2 value.
	--	it literally just sticks a negative sign in front
	
	return -CartisianVector2
end
lib.InvertCartisian2 =InvertCartisian2 -- Please remove when possible
lib.invertCartisian2 =InvertCartisian2 -- Please remove when possible

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
lib.lerp = LerpNumber

return lib
