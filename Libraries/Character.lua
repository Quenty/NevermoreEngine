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

local NevermoreEngine    = _G.NevermoreEngine
local LoadCustomLibrary = NevermoreEngine.LoadLibrary;

local qSystems          = LoadCustomLibrary('qSystems')
local RawCharacter      = LoadCustomLibrary('RawCharacter')

qSystems:Import(getfenv(0));

local safeLib = {}

for functionName, libraryItem in pairs(RawCharacter) do
	if type(functionName) ~= "string" then
		error("functionName '"..tostring(functionName).."' a '"..Type.GetType(functionName).."' value should be a string")
	end
	if type(libraryItem) == "function" and functionName:lower() ~= "import" then
		safeLib[functionName] = function(character, ...) 
			if CheckCharacter(character) then
				libraryItem(character, ...)
			else
				error("The character did not have a correct head, torso, or humanoid, so '"..functionName.."' could not execute")
			end
		end
	end
end

NevermoreEngine.RegisterLibrary('Character', safeLib)