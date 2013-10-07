while not _G.NevermoreEngine do wait(0) end

local Players           = Game:GetService('Players')
local StarterPack       = Game:GetService('StarterPack')
local StarterGui        = Game:GetService('StarterGui')
local Lighting          = Game:GetService('Lighting')
local Debris            = Game:GetService('Debris')
local Teams             = Game:GetService('Teams')
local BadgeService      = Game:GetService('BadgeService')
local InsertService     = Game:GetService('InsertService')
local Terrain           = Workspace.Terrain

local NevermoreEngine   = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')

qSystems:Import(getfenv(0));

local lib = {}

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
	return -CartisianVector2
end
lib.InvertCartisian2 =InvertCartisian2
lib.invertCartisian2 =InvertCartisian2

NevermoreEngine.RegisterLibrary('qMath', lib)