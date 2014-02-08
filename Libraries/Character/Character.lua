local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NevermoreEngine   = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary = NevermoreEngine.LoadLibrary

local RawCharacter      = LoadCustomLibrary("RawCharacter")
local qSystems          = LoadCustomLibrary("qSystems")


qSystems:Import(getfenv(0));

local safeLib = {}

--- This library handles making sure it is safe to use RawCharacter functions. 
-- @author Quenty
-- Last modified January 14th, 2013

--[[-- Change Log --

January 19th, 2014
- Updated to include output parser

--]]

for functionName, libraryItem in pairs(RawCharacter) do
	if type(functionName) ~= "string" then
		error("[Character] - functionName '"..tostring(functionName).."' a '"..Type.GetType(functionName).."' value should be a string")
	end
	if type(libraryItem) == "function" and functionName:lower() ~= "import" then
		safeLib[functionName] = function(character, ...) 
			if CheckCharacter(character) then
				libraryItem(character, ...)
			else
				error("[Character] - The character did not have a correct head, torso, or humanoid, so '"..functionName.."' could not execute")
			end
		end
	end
end

return safeLib