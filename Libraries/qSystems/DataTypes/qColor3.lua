local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qString           = LoadCustomLibrary("qString")
local qMath             = LoadCustomLibrary("qMath")

qSystems:Import(getfenv(0));

local RbxUtility = LoadLibrary("RbxUtility")

local lib = {}

--- Manipulation and seralization of Color3 Values
-- @author Quenty
-- Last modified January 3rd, 2013

local function EncodeColor3(Color3)
	--- Encodes a Color3 in JSON
	-- @param Color3 The Color3 to encode
	-- @return String The string representation in JSON of the Color3 value.

	local NewData = {
		Color3.r;
		Color3.g;
		Color3.b;
	}

	return RbxUtility.EncodeJSON(NewData)
end
lib.EncodeColor3 = EncodeColor3
lib.encodeColor3 = EncodeColor3
lib.Encode = EncodeColor3
lib.encode = EncodeColor3

local function DecodeColor3(Data)
	--- decode's a previously encoded Color3.
	-- @param Data String of JSON, that was encoded.
	-- @return Color3 if it could be decoded, otherwise, nil
	
	if Data then
		local DecodedData = RbxUtility.DecodeJSON(Data)
		if DecodedData then
			return Color3.new(unpack(DecodedData))
		else
			return nil
		end
	else
		return nil
	end
end
lib.DecodeColor3 = DecodeColor3
lib.decodeColor3 = DecodeColor3
lib.Decode = DecodeColor3
lib.decode = DecodeColor3

local LerpNumber = qMath.LerpNumber

local function LerpColor3(ColorOne, ColorTwo, Alpha)
	--- Interpolates between two color3 values. 
	-- @param ColorOne The first Color
	-- @param ColorTwo The second color
	-- @param Alpha The amount to interpolate between
	-- @return The resultent Color3 value. 
	
	return Color3.new(LerpNumber(ColorOne.r, ColorTwo.r, Alpha), LerpNumber(ColorOne.g, ColorTwo.g, Alpha), LerpNumber(ColorOne.b, ColorTwo.b, Alpha))
end
lib.LerpColor3 = LerpColor3
lib.lerpColor3 = LerpColor3

return lib