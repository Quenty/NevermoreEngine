-- Character.lua
-- This library handles making sure it is safe to use RawCharacter functions. 
-- @author Quenty

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LoadCustomLibrary = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))

local qSystems          = LoadCustomLibrary("qSystems")
local Type              = LoadCustomLibrary("Type")

local CheckCharacter    = qSystems.CheckCharacter

local safeLib = {}

for functionName, libraryItem in pairs(LoadCustomLibrary("RawCharacter")) do
	if type(functionName) ~= "string" then
		error("[Character] - functionName '"..tostring(functionName).."' a '"..Type(functionName).."' value should be a string")
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
