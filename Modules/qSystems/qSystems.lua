local Players            = game:GetService("Players")
local StarterPack        = game:GetService("StarterPack")
local StarterGui         = game:GetService("StarterGui")
local Lighting           = game:GetService("Lighting")
local Debris             = game:GetService("Debris")
local Teams              = game:GetService("Teams")
local BadgeService       = game:GetService("BadgeService")
local InsertService      = game:GetService("InsertService")
local HttpService        = game:GetService("HttpService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local TestService        = game:GetService("TestService")
local Terrain            = Workspace.Terrain

local NevermoreEngine    = require(ReplicatedStorage:WaitForChild("NevermoreEngine"))
local LoadCustomLibrary  = NevermoreEngine.LoadLibrary

-------------------------
-- Documentation Stuff --
-------------------------

-- @author Quenty
-- Revised Janurary 4th, 2014
-- This script handles a variety of tasks and generic functions that are useful for
-- ROBLOX game developement. It is meant to be imported into another script.
-- @return The qSystems library. 

--[[
Updates and Changes log
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
	
local Type                    = LoadCustomLibrary('Type')

local lib                     = {}

-----------------------
-- General functions --
-----------------------

-- Creates a signal, like before, but this time uses internal Lua signals that allow for the sending of recursive
-- tables versus using ROBLOX's parsing system. 
local function CreateSignalInternal()

	local this = {}
	local mListeners = {}
	local mListenerCount = 0
	local mWaitProxy = nil
	local mWaitReturns = nil
	local mHasWaiters = false

	function this:connect(func)
		if self ~= this then error("connect must be called with `:`, not `.`", 2) end
		if type(func) ~= 'function' then
			error("Argument #1 of connect must be a function, got a "..type(func), 2)
		end
		mListenerCount = mListenerCount + 1
		local conn = {}
		function conn:disconnect()
			if mListeners[conn] then
				mListeners[conn] = nil
				mListenerCount = mListenerCount - 1
			end
		end
		mListeners[conn] = func
		return conn
	end

	function this:disconnect()
		if self ~= this then error("disconnect must be called with `:`, not `.`", 2) end
		for k, v in pairs(mListeners) do
			mListeners[k] = nil
		end
		mListenerCount = 0
	end

	function this:wait()
		if self ~= this then error("wait must be called with `:`, not `.`", 2) end
		if not mWaitProxy then
			mWaitProxy = Instance.new('BoolValue')
		end
		mHasWaiters = true
		mWaitProxy.Changed:wait()
		return unpack(mWaitReturns)
	end

	function this:fire(...)
		if self ~= this then error("fire must be called with `:`, not `.`", 2) end
		local arguments;
		if mListenerCount > 0 or mHasWaiters then
			arguments = {...}
		end
		if mHasWaiters then
			mHasWaiters = false
			mWaitReturns = arguments
			mWaitProxy.Value = not mWaitProxy.Value
			mWaitReturns = nil
		end
		if mListenerCount > 0 then
			for _, handlerFunc in pairs(mListeners) do
				Spawn(function()
					handlerFunc(unpack(arguments))
				end)
			end
		end
	end

	function this:fireSync(...)
		if self ~= this then error("fire must be called with `:`, not `.`", 2) end
		local arguments;
		if mListenerCount > 0 or mHasWaiters then
			arguments = {...}
		end
		if mHasWaiters then
			mHasWaiters = false
			mWaitReturns = arguments
			mWaitProxy.Value = not mWaitProxy.Value
			mWaitReturns = nil
		end
		if mListenerCount > 0 then
			for _, handlerFunc in pairs(mListeners) do
				handlerFunc(...)
			end
		end
	end

	function this:destroy()
		this:disconnect()
		this.mListeners = nil
		this.mListenerCount = nil
		this.mWaitProxy = nil
		this.mWaitReturns = nil
		this.mHasWaiters = nil
		this.destroy = nil
		this.Destroy = nil
		this.fire = nil
		this.wait = nil
		this.connect = nil
		this.fireSync = nil
		this = nil
	end

	function this:Destroy()
		this:destroy()
	end
	
	return this;
end
lib.CreateSignalInternal = CreateSignalInternal
lib.createSignalInternal = CreateSignalInternal
lib.create_internal_signal = CreateSignalInternal
lib.CreateSignal = CreateSignalInternal 
lib.createSignal = CreateSignalInternal
lib.create_signal = CreateSignalInternal

local function RoundNumber(Number, Divider)
	-- Rounds a Number, with 1.5 rounding up to 2, and so forth, by default. 
	-- @param Number the Number to round
	-- @param [Divider] optional Number of which to "round" to. If nothing is given, it will default to 1. 

	Divider = Divider or 1

	return (math.floor((Number/Divider)+0.5)*Divider)
end
lib.roundNumber = RoundNumber
lib.RoundNumber = RoundNumber
lib.round_number = RoundNumber
lib.Round = RoundNumber
lib.round = RoundNumber


local function Modify(Instance, Values)
	-- Modifies an Instance by using a table.  

	assert(type(Values) == "table", "Values is not a table");

	for Index, Value in next, Values do
		if type(Index) == "number" then
			Value.Parent = Instance
		else
			Instance[Index] = Value
		end
	end
	return Instance
end
lib.modify = Modify
lib.Modify = Modify


local function Make(ClassType, Properties)
	-- Using a syntax hack to create a nice way to Make new items.  

	return Modify(Instance.new(ClassType), Properties)
end
lib.make = Make;
lib.Make = Make;


local function WaitForChild(Parent, Name, TimeLimit)
	-- Waits for a child to appear. Not efficient, but it shoudln't have to be. It helps with debugging. 
	-- Useful when ROBLOX lags out, and doesn't replicate quickly.
	-- @param TimeLimit If TimeLimit is given, then it will return after the timelimit, even if it hasn't found the child.

	assert(Parent ~= nil, "Parent is nil")
	assert(type(Name) == "string", "Name is not a string.")

	local Child     = Parent:FindFirstChild(Name)
	local StartTime = tick()
	local Warned    = false

	while not Child and Parent do
		wait(0)
		Child = Parent:FindFirstChild(Name)
		if not Warned and StartTime + (TimeLimit or 5) <= tick() then
			Warned = true
			warn("Infinite yield possible for WaitForChild(" .. Parent:GetFullName() .. ", " .. Name .. ")")
			if TimeLimit then
				return Parent:FindFirstChild(Name)
			end
		end
	end

	if not Parent then
		warn("Parent became nil.")
	end

	return Child
end
lib.waitForChild = WaitForChild
lib.WaitForChild = WaitForChild
lib.wait_for_child = WaitForChild

local function CallOnChildren(Instance, FunctionToCall)
	-- Calls a function on each of the children of a certain object, using recursion.  

	FunctionToCall(Instance)

	for _, Child in next, Instance:GetChildren() do
		CallOnChildren(Child, FunctionToCall)
	end
end
lib.callOnChildren = CallOnChildren
lib.CallOnChildren = CallOnChildren
lib.call_on_children = CallOnChildren


local function getNearestParent(instance, className)
	-- Returns the nearest parent of a certain class, or returns nil

	local ancestor = instance
	repeat
		ancestor = ancestor.Parent
		if ancestor == nil then
			return nil
		end
	until ancestor:IsA(className)
	return ancestor
end
lib.getNearestParent = getNearestParent;
lib.GetNearestParent = getNearestParent;
lib.get_nearest_parent = getNearestParent;


local function GetHumanoid(Descendant)
	-- Return's a humanoid in the parent structure if it can find it. Intended to be used in Workspace only.
	-- Useful for weapon scripts, and all that, especially to work on non player targets.
	-- Will scan *up* to workspace. If workspace has a humanoid in it, it won't find it.

	-- Will work even if there are non-humanoid objects named "Humanoid"
	-- However, only works on objects named "Humanoid" (this is intentional)

	-- @param Descendant The child you're searching up from. Really, this is for weapon scripts. 

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

		if Descendant.Parent and Descendant.Parent ~= Workspace then
			Descendant = Descendant.Parent
		else
			return nil
		end
	end
end
lib.GetHumanoid = GetHumanoid
lib.getHumanoid = GetHumanoid


local function GetCharacter(Descendant)
	-- Returns the Player and Charater that a descendent is part of, if it is part of one.
	-- @param Descendant A child of the potential character. 

	local Charater = Descendant
	local Player   = Players:GetPlayerFromCharacter(Charater)

	while not Player do
		if Charater.Parent then
			Charater = Charater.Parent
			Player   = Players:GetPlayerFromCharacter(Charater)
		else
			return nil
		end
	end

	-- Found the player, character must be true.
	return Charater, Player
end
lib.getCharacter = GetCharacter
lib.GetCharacter = GetCharacter
lib.get_character = GetCharacter

lib.GetPlayerFromCharacter = GetCharacter
lib.getPlayerFromCharacter = GetCharacter
lib.get_player_from_character = GetCharacter

local function CheckPlayer(Player)
	--- Makes sure a player has all necessary components.
	-- @return Boolean If the player has all the right components

	return Player and Player:IsA("Player") 
end
lib.checkPlayer = CheckPlayer
lib.CheckPlayer = CheckPlayer
lib.check_player = CheckPlayer


local function CheckCharacter(Player)
	-- Makes sure a character has all the right "parts"
	
	if CheckPlayer(Player) then
		local Character = Player.Character;

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
lib.checkCharacter = CheckCharacter
lib.CheckCharacter = CheckCharacter
lib.check_character = CheckCharacter


local function GetIndexByValue(Values, Value)
	-- Return's the index of a Value. 

	for Index, TableValue in next, Values do
		if Value == TableValue then
			return Index;
		end
	end

	return nil
end
lib.getIndexByValue = GetIndexByValue
lib.GetIndexByValue = GetIndexByValue
lib.get_index_by_value = GetIndexByValue

lib.getIndex = getIndexByValue
lib.GetIndex = getIndexByValue
lib.get_index = getIndexByValue

local function Class(Constructor, Metatable)
	--- Provides a wrapper for new classes. 

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
lib.class = Class;
lib.Class = Class;

local function Sign(Number)
	-- Return's the mathetmatical sign of an object
	if Number == 0 then
		return 0
	elseif Number > 0 then
		return 1
	else
		return -1
	end
end
lib.Sign = Sign
lib.sign = Sign


return lib