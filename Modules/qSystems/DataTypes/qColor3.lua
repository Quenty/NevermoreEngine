local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local qSystems          = LoadCustomLibrary("qSystems")
local qString           = LoadCustomLibrary("qString")
local qMath             = LoadCustomLibrary("qMath")
local Easing            = LoadCustomLibrary("Easing")

local Round = qSystems.Round

local RbxUtility = LoadLibrary("RbxUtility")

local lib = {}

--- Manipulation and seralization of Color3 Values
-- @author Quenty
-- Last modified September 6th, 2014

local function EncodeColor3(Color3)
	--- Encodes a Color3 in JSON
	-- @param Color3 The Color3 to encode
	-- @return String The string representation in JSON of the Color3 value.

	local NewData = {
		Color3.r;
		Color3.g;
		Color3.b;
	}

	return HttpService:JSONEncode(NewData)
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
		local DecodedData = HttpService:JSONDecode(Data) --RbxUtility.DecodeJSON(Data)
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



-- Code from Anaminus --
-- http://asset-markotaris.rhcloud.com/45860975
local function Color3ToByte(ColorOne)
    return Round(ColorOne.r*255), Round(ColorOne.g*255), Round(ColorOne.b*255)
end
lib.Color3ToByte = Color3ToByte

local function RGBtoHSL(R,G,B)
	-- Converts an RGB color from RGB to HSL (Hue, Saturation, Luminance)
	-- @param R number [0, 1], the red value
	-- @param G number [0, 1], the green value
	-- @param B number [0, 1], the blue value

    local Min,Max = math.min(R,G,B), math.max(R,G,B)
    local dMax = Max - Min
    local H,S,L = 0,0,(Max + Min)/2
    if dMax ~= 0 then
        if L < 0.5 then
            S = dMax/(Max + Min)
        else
            S = dMax/(2 - Max - Min)
        end
        local dR = (((Max-R)/6)+(dMax/2))/dMax
        local dG = (((Max-G)/6)+(dMax/2))/dMax
        local dB = (((Max-B)/6)+(dMax/2))/dMax
        if R == Max then
            H = dB - dG
        elseif G == Max then
            H = (1/3)+dR-dB
        elseif B == Max then
            H = (2/3)+dG-dR
        end

        if H < 0 then H = H+1 end
        if H > 1 then H = H-1 end
    end
    return H,S,L
end
lib.RGBtoHSL = RGBtoHSL

local function Color3ToHSL3(Color)
	-- @return A Color3 version, but in HSL (numbers range) [0, 1]

	return Color3.new(RGBtoHSL(Color.r, Color.g, Color.b))
end
lib.Color3ToHSL3 = Color3ToHSL3

local function Color3ToHSL(Color)
	-- @return A Color3 version, but in HSL (numbers range) [0, 1]

	return RGBtoHSL(Color.r, Color.g, Color.b)
end
lib.Color3ToHSL = Color3ToHSL


local function HueToRGB(v1,v2,vH)
   if vH < 0 then vH = vH + 1 end
   if vH > 1 then vH = vH - 1 end
   if 6*vH < 1 then return v1+(v2-v1)*6*vH end
   if 2*vH < 1 then return v2 end
   if 3*vH < 2 then return v1+(v2-v1)*((2/3)-vH)*6 end
   return v1
end
lib.HueToRGB = HueToRGB

local function HSLtoRGB(H,S,L)
	--- Converts HSL to Color3

    local R,G,B
    if S == 0 then
        return L,L,L
    else
        local v2 = L < 0.5 and L*(1+S) or (L+S)-(S*L)
        local v1 = 2*L-v2
        return
            HueToRGB(v1,v2,H+(1/3)),
            HueToRGB(v1,v2,H),
            HueToRGB(v1,v2,H-(1/3))
    end
end
lib.HSLtoRGB = HSLtoRGB

local function HSL3toColor3(ColorHSL)
	-- @return A Color3 version of the HSL

	return Color3.new(HSLtoRGB(ColorHSL.r, ColorHSL.g, ColorHSL.b))
end
lib.HSL3toColor3 = HSL3toColor3


-- written by Quenty

local function SetSaturation(Color, Saturation)
	-- @param Color The color to desaturate
	-- @param Saturation A number from 0 to 1 of how saturated it should be. 0 will be complete desaturation.

	local H, S, L = Color3ToHSL(Color)
	return Color3.new(HSLtoRGB(H, Saturation, L))
end
lib.SetSaturation = SetSaturation

local function SetLuminance(Color, Luminance)
	-- @param Color The color to set brightness
	-- @param [Luminance] A number from 0 to 1 of how bright it should be. 0 will be complete dark.

	local H, S, L = Color3ToHSL(Color)
	return Color3.new(HSLtoRGB(H, S, Luminance))
end
lib.SetLuminance = SetLuminance

local function AdjustColorTowardsWhite(Color)
	--- We'll use this to try to make text more readable. Mess with saturation and Luminance, while keeping hue
	-- @param CloseToWhite [0, 1] 1 is the closest to white, I think? 

	local H, S, L = Color3ToHSL(Color)
	
	local LightningFactor = 0.75-- The LightningFactor determines how bright it is. 1 = white, 0 = no change.

	local Difference = 1 - L
	L = L + Difference * (1-S) * LightningFactor -- We're only lighting desaturated stuff...

	-- Problem: Darker colors are hard to see. L indicates darkness. So we'll modify L based upon saturation (that is, how much color).
	-- We'll then desaturate bright colors, but we want to saturate nonsaturated ones. And... black has to stay saturation 0.

	--S = S * 0.8
	S = Easing.inOutCubic(S, 0, 1, 0.8) -- Uh... I... ok. this will do.

	return Color3.new(HSLtoRGB(H, S, L))
end
lib.AdjustColorTowardsWhite = AdjustColorTowardsWhite

local function SetSaturationAndLuminance(Color, Saturation, Luminance)

	local H, S, L = Color3ToHSL(Color)
	return Color3.new(HSLtoRGB(H, Saturation, Luminance))
end
lib.SetSaturationAndLuminance = SetSaturationAndLuminance

return lib