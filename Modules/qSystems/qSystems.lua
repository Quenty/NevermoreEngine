local Players = game:GetService("Players")

-------------------------
-- Documentation Stuff --
-------------------------

-- Revised November 13th, 2015
-- @author Quenty
-- This script handles a variety of tasks and generic functions that are useful for
-- ROBLOX game developement. It is meant to be imported into another script.
-- @return The qSystems library. 

--[[
Updates and Changes log
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
	
local lib = {}

-----------------------
-- General functions --
-----------------------

local function RoundNumber(Number, Divider)
	-- Rounds a Number, with 1.5 rounding up to 2, and so forth, by default. 
	-- @param Number the Number to round
	-- @param [Divider] optional Number of which to "round" to. If nothing is given, it will default
	--     to 1.

	Divider = Divider or 1

	return math.floor(Number/Divider+0.5)*Divider
end
lib.RoundNumber = RoundNumber
lib.Round = RoundNumber

local function Modify(Instance, Values)
	--- Modifies an Instance by using a table.  
	-- @param Instance The instance to modify
	-- @param Values A table with keys as the value to change, and the value as the property to
	--     assign

	assert(type(Values) == "table", "Values is not a table")

	for Index, Value in next, Values do
		if type(Index) == "number" then
			Value.Parent = Instance
		elseif type(Value) == "function" then
			Instance[Index]:connect(Value)
		elseif Index ~= "Parent" then
			Instance[Index] = Value
		end
	end
	if Values["Parent"] then -- If Parent is in Values, change it last
		Instance["Parent"] = Values["Parent"]
	end
	return Instance
end

local function Make(ClassType, Properties, ...)
	--- Using a syntax hack to create a nice way to Make new items.  
	-- @param ClassType The type of class to instantiate
	-- @param Properties The properties to use
	-- @returns object of ClassType with Properties
	-- @param {...} if used, @returns an object for each subsequent table that is a modification to Properties
	-- 	This would be used for creating a custom "default" list of properties so you don't need to rewrite the same properties over and over.
	local objects = {...}
	if #objects > 0 then
		for index, objectProps in next, objects do
			objects[index] = Modify(Modify(Instance.new(ClassType), objectProps), Properties)
		end
		return unpack(objects)
	else
		return Modify(Instance.new(ClassType), Properties)
	end
end

lib.Modify = Modify
lib.Make = Make

local function WaitForChild(Parent, Name, TimeLimit)
	-- Waits for a child to appear. Not efficient, but it shoudln't have to be. It helps with
	-- debugging. Useful when ROBLOX lags out, and doesn't replicate quickly. Will warn
	-- @param Parent The Parent to search in for the child.
	-- @param Name The name of the child to search for
	-- @param TimeLimit If TimeLimit is given, then it will return after the t imelimit, even if it
	--     hasn't found the child.

	assert(Parent, "Parent is nil")
	assert(type(Name) == "string", "Name is not a string.")

	local Child     = Parent:FindFirstChild(Name)
	local StartTime = tick()
	local Warned    = false

	while not Child do
		wait()
		Child = Parent:FindFirstChild(Name)
		if not Warned and StartTime + (TimeLimit or 5) <= tick() then
			Warned = true
				warn("[WaitForChild] - Infinite yield possible for WaitForChild(" .. Parent:GetFullName() .. ", " .. Name .. ")\n" .. debug.traceback())
			if TimeLimit then
				return Parent:FindFirstChild(Name)
			end
		end
	end

	return Child
end
lib.WaitForChild = WaitForChild

local function CallOnChildren(Instance, FunctionToCall)
	--- Calls a function on each of the children of a certain object, using recursion.  
	-- Exploration note: Parents are always called before children.
	-- @param Instance The Instance to search for
	-- @param FunctionToCall The function to call. Will be called on the Instance and then on all
	--     descendants.
	
	FunctionToCall(Instance)

	for _, Child in next, Instance:GetChildren() do
		CallOnChildren(Child, FunctionToCall)
	end
end
lib.CallOnChildren = CallOnChildren

local function GetNearestParent(Instance, ClassName)
	--- Returns the nearest parent of a certain class, or returns nil
	-- @param Instance The instance to start searching
	-- @param ClassName The class to look for

	local Ancestor = Instance
	repeat
		Ancestor = Ancestor.Parent
		if Ancestor == nil then
			return nil
		end
	until Ancestor:IsA(ClassName)

	return Ancestor
end
lib.GetNearestParent = GetNearestParent

local function GetHumanoid(Descendant)
	---- Retrieves a humanomid from a descendant (Players only).
	-- @param Descendant The child you're searching up from. Really, this is for weapon scripts. 
	-- @return A humanoid in the parent structure if it can find it. Intended to be used in
	--     workspace  only. Useful for weapon scripts, and all that, especially to work on non
	--     player targets. Will scan *up* to workspace . If workspace   has a humanoid in it, it
	--     won't find it.
	-- Will work even if there are non-humanoid objects named "Humanoid" However, only works on
	-- objects named "Humanoid" (this is intentional)


	while true do
		local Humanoid = Descendant:FindFirstChild("Humanoid")

		if Humanoid then
			if Humanoid:IsA("Humanoid") then
				return Humanoid
			else -- Incase there are other humanoids in there.
				for _, Item in pairs(Descendant:GetChildren()) do
					if Item.Name == "Humanoid" and Item:IsA("Humanoid") then
						return Item
					end
				end
			end
		end

		if Descendant.Parent and Descendant:IsDescendantOf(workspace) then
			Descendant = Descendant.Parent
		else
			return nil
		end
	end
end
lib.GetHumanoid = GetHumanoid

local function GetCharacter(Descendant)
	--- Returns the Player and Character that a descendent is part of, if it is part of one.
	-- @param Descendant A child of the potential character. 
	-- @return The character found.

	local Character = Descendant
	local Player   = Players:GetPlayerFromCharacter(Character)

	while not Player do
		if Character.Parent then
			Character = Character.Parent
			Player   = Players:GetPlayerFromCharacter(Character)
		else
			return nil
		end
	end

	-- Found the player, character must be true.
	return Character, Player
end
lib.GetCharacter = GetCharacter
lib.GetPlayerFromCharacter = GetCharacter

local function CheckPlayer(Player)
	--- Makes sure a player has all necessary components.
	-- @param Player The Player to check for
	-- @return Boolean If the player has all the right components

	return Player and Player:IsA("Player") and Player:IsDescendantOf(Players)
end
lib.CheckPlayer = CheckPlayer

local function CheckCharacter(Player)
	--- Makes sure a character has all the right "parts". This also validates the player's status as
	--  a player. This is useful when you want to load a character, as ROBLOX's character added
	--  event doesn't guarantee loaded character status.
	-- @param Player The player to search for
	-- @return Boolean, True if it's good, false if it's not.
	
	if CheckPlayer(Player) then
		local Character = Player.Character

		if Character then
			return Character.Parent
				and Character:FindFirstChild("Humanoid")
				and Character:FindFirstChild("HumanoidRootPart")
				and Character:FindFirstChild("Torso") 
				and Character:FindFirstChild("Head") 
				and Character.Humanoid:IsA("Humanoid")
				and Character.Head:IsA("BasePart")
				and Character.Torso:IsA("BasePart")
				and true
		end
	else
		warn("[CheckCharacter] - Character Check failed!")
	end

	return nil
end
lib.CheckCharacter = CheckCharacter


local function GetIndexByValue(Values, Value)
	--- Return's the index of a Value in a table.
	-- @param Values A table to search for 
	-- @value the Value to search for
	-- @return THe key of the value. Returns nil if it can't find it.

	for Index, TableValue in next, Values do
		if Value == TableValue then
			return Index
		end
	end

	return nil
end
lib.GetIndexByValue = GetIndexByValue


local function Class(Constructor, Metatable)
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

local function Sign(Number)
	--- Return's the mathetmatical sign of an object
	-- @param Number The number to use
	-- @return An int from [-1, 1]. 

	if Number == 0 then
		return 0
	elseif Number > 0 then
		return 1
	else
		return -1
	end
end
lib.Sign = Sign

return lib
