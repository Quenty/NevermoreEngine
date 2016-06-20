--[[
Deprecated Library

Updates and Changes log
June 20th, 2016
- Deprecated Library

November 21st, 2015
- Removed Signal library, and Nevermore dependency

November 15th, 2015
- Updated documentation
- Cleaned up code a bit

November 17th, 2014
- Removed importing into the environment

August 18th, 2014
- Removed isA method
- Cleaned up commented code
- Removed classOrServiceAlreadyExists

August 14th, 2014
- Updated Make() so it doesn't create a new function to function (no pun intended)
- Removed warn() function, as ROBLOX has a native one.

March 6th, 2014
- Updated WaitForChild to have a time limit
- Modified WaitForChild to make sure the parent isn't nil

February 9th, 2014
- Updated CheckCharacter to check for HumanoidRootPart

January 26th, 2014
- Removed old code
- Fixed issue with constructor and class system

January 25th, 2014
- Updated Class System to return extra parameters from constructor pass constructed object. 

Janurary 4th, 2014
- Removed the class and service list for performance reasons

January 2nd, 2014
- Add Sign function

January 1st, 2014
- Fixed CheckCharacter to work with Local scripts (Replication change)

December 28th, 2013
- Removed VerifyArg and error functions
- Updated Headercode for new NevermoreEngine
- Started change log
- Setup qSystems to work with module scripts.
- Added new alias to roundnumber (Round)
]]

local Players = game:GetService("Players")
local Load = require(game:GetService("ReplicatedStorage"):WaitForChild("NevermoreEngine")).LoadLibrary
local qMath = Load("qMath")
local qPlayer = Load("qPlayer")
local qTable = Load("qTable")

local lib = {}

lib.Make = Load("Make")
lib.Modify = Load("Modify")
lib.WaitForChild = Load("WaitForChild")
lib.CallOnChildren = Load("CallOnChildren")
lib.GetNearestParent = Load("GetNearestParent")

lib.GetHumanoid = qPlayer.GetHumanoid
lib.CheckPlayer = qPlayer.CheckPlayer
lib.GetCharacter = qPlayer.GetCharacter
lib.CheckCharacter = qPlayer.CheckCharacter
lib.GetPlayerFromCharacter = qPlayer.GetCharacter

lib.GetIndexByValue = qTable.GetIndexByValue

lib.RoundNumber = qMath.Round
lib.Round = qMath.Round
lib.Sign = qMath.Sign

local function Class(Constructor, Metatable) -- Please do not use, ever
	
	--- Provides a wrapper for new classes. Abuses closures to create this class. It's recommended
	--  this class system not be used. Left here for legacy reasons. This sort of class system is
	--  more efficient in terms of calcuation speed, but costs more to construct and uses a lot more
	--  memory. In most cases, the fact it's linked to qSystems makes it unreasonable to use this
	--  class system. Furthermore, this class system does not do inheritance well.
	
	-- @param Constructor A function that's passed the parameters `newClass` and any extra arguments
	--     passed in on construction
	-- @param [Metatable] The metatable to assign to the new class. 
	-- @return The constructor of the class to use

	local ConstructNewClass

	if Metatable then
		function ConstructNewClass(...)
			local newClass = {}

			setmetatable(newClass, Metatable)

			local Results = {Constructor(newClass, ...)}
			return newClass, unpack(Results)
		end
	else
		function ConstructNewClass(...)
			local newClass = {}
			local Results = {Constructor(newClass, ...)}
			return newClass, unpack(Results)
		end
	end

	return ConstructNewClass
end
lib.Class = Class

return lib
