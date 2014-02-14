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
-- local classList               = {}
-- local serviceList             = {}
-- local classAndServiceNameList = {}

-- setmetatable(classList, {__mode = "k"})

-----------------------
-- General functions --
-----------------------
local function CreateSignal() -- Ripped directly from RbxUtility. Modified for :Destroy()
	--[[
	A 'Signal' object identical to the internal RBXScriptSignal object in it's public API and semantics. This function 
	can be used to create "custom events" for user-made code.
	API:
	Method :connect( function handler )
		Arguments:   The function to connect to.
		Returns:     A new connection object which can be used to disconnect the connection
		Description: Connects this signal to the function specified by |handler|. That is, when |fire( ... )| is called for
		             the signal the |handler| will be called with the arguments given to |fire( ... )|. Note, the functions
		             connected to a signal are called in NO PARTICULAR ORDER, so connecting one function after another does
		             NOT mean that the first will be called before the second as a result of a call to |fire|.

	Method :disconnect()
		Arguments:   None
		Returns:     None
		Description: Disconnects all of the functions connected to this signal.

	Method :fire( ... )
		Arguments:   Any arguments are accepted
		Returns:     None
		Description: Calls all of the currently connected functions with the given arguments.

	Method :wait()
		Arguments:   None
		Returns:     The arguments given to fire
		Description: This call blocks until 
	]]

	local this = {}

	local mBindableEvent = Instance.new('BindableEvent')
	local mAllCns = {} --all connection objects returned by mBindableEvent::connect

	--main functions
	function this:connect(func)
		if self ~= this then error("connect must be called with `:`, not `.`", 2) end
		if type(func) ~= 'function' then
			error("Argument #1 of connect must be a function, got a "..type(func), 2)
		end
		local cn = mBindableEvent.Event:connect(func)
		mAllCns[cn] = true
		local pubCn = {}
		function pubCn:disconnect()
			cn:disconnect()
			mAllCns[cn] = nil
		end
		return pubCn
	end
	function this:disconnect()
		if self ~= this then error("disconnect must be called with `:`, not `.`", 2) end
		for cn, _ in pairs(mAllCns) do
			cn:disconnect()
			mAllCns[cn] = nil
		end
	end
	function this:wait()
		if self ~= this then error("wait must be called with `:`, not `.`", 2) end
		return mBindableEvent.Event:wait()
	end
	function this:fire(...)
		if self ~= this then error("fire must be called with `:`, not `.`", 2) end
		mBindableEvent:Fire(...)
	end

	function this:destroy()
		mBindableEvent:Destroy()
		this.destroy = nil
		this.Destroy = nil
		this.fire = nil
		this.wait = nil
		this.connect = nil
		this.mAllCns = nil
	end

	function this:Destroy()
		this:destroy()
	end

	return this
end
lib.CreateSignal = CreateSignal
lib.createSignal = CreateSignal
lib.create_signal = CreateSignal

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

local function roundNumber(number, divider)
	-- Rounds a number, with one half rounding up.
	-- @param Number the number to round
	-- @param [divider] optinoal number of which to "round" to. If nothing is given, it will default to 1. 

	divider = divider or 1

	return (math.floor((number/divider)+0.5)*divider)
end
lib.roundNumber = roundNumber
lib.RoundNumber = roundNumber
lib.round_number = roundNumber
lib.Round = roundNumber
lib.round = roundNumber

local function warn(warningText)
	-- Generates a safe 'error', so you get nice red warning text...
	-- @oaran warningText The text to warn with

	Spawn(function()
		TestService:Warn(false, warningText)
	end)

end
lib.warn = warn;
lib.Warn = warn;


local function modify(instance, values)
	-- Modifies an instance by using a table.  

	for key, value in next, values do
		if type(key) == "number" then
			value.Parent = instance
		else
			instance[key] = value
		end
	end
	return instance
end
lib.modify = modify;
lib.Modify = modify;


local function make(type)
	-- Using a syntax hack to create a nice way to make new items.  

	return function(values)
		local newInstance = Instance.new(type)
		return modify(newInstance, values)
	end
end
lib.make = make;
lib.Make = make;


local function waitForChild(parent, name)
	-- Waits for a child to appear.   
	-- Useful when ROBLOX lags out, and doesn't replicate quickly.

	local child = parent:FindFirstChild(name)
	local startTime = time()
	local warned = false
	while not child do
		wait(0)
		child = parent:FindFirstChild(name)
		if not warned and startTime + 5 <= time() then
			warned = true
			warn("Infinite yield possible for WaitForChild("..name..") with parent @ "..parent:GetFullName(), 3)
		end
	end
	return child;
end
lib.waitForChild = waitForChild;
lib.WaitForChild = waitForChild;
lib.wait_for_child = waitForChild;

local CallOnChildren

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


local function getCharacter(descendant)
	-- Returns the Player and Charater that a descendent is part of, if it is part of one.

	local character = descendant
	local player = Players:GetPlayerFromCharacter(character)

	while not player do
		if character.Parent then
			character = character.Parent;
			player = Players:GetPlayerFromCharacter(character)
		else
			return nil
		end
	end

	return character, player;
end
lib.getCharacter = getCharacter
lib.GetCharacter = getCharacter
lib.get_character = getCharacter

lib.GetPlayerFromCharacter = getCharacter
lib.getPlayerFromCharacter = getCharacter
lib.get_player_from_character = getCharacter

local function checkPlayer(player)
	--- Makes sure a player has all necessary components.
	-- @return Boolean If the player has all the right components

	return player and player:IsA("Player") 
		and player:FindFirstChild("Backpack") 
		and player:FindFirstChild("StarterGear")
		-- and player.PlayerGui:IsA("PlayerGui") -- PlayerGui does not replicate to other clients. If FilteringEnabled is true, does not replicate to Server
end
lib.checkPlayer = checkPlayer
lib.CheckPlayer = checkPlayer
lib.check_player = checkPlayer


local function checkCharacter(player)
	-- Makes sure a character has all the right "parts"
	local character = player.Character;

	if character and checkPlayer(player) then
		
		return character:FindFirstChild("Humanoid")
			and character:FindFirstChild("HumanoidRootPart")
			and character:FindFirstChild("Torso") 
			and character:FindFirstChild("Head") 
			and character.Humanoid:IsA("Humanoid")
			and character.Head:IsA("BasePart")
			and character.Torso:IsA("BasePart")
	end

	return nil;
end
lib.checkCharacter = checkCharacter
lib.CheckCharacter = checkCharacter
lib.check_character = checkCharacter


local function getIndexByValue(values, value)
	-- Return's the index of a value. 

	for index, tableValue in next, values do
		if value == tableValue then
			return index;
		end
	end

	return nil
end
lib.getIndexByValue = getIndexByValue
lib.GetIndexByValue = getIndexByValue
lib.get_index_by_value = getIndexByValue

lib.getIndex = getIndexByValue
lib.GetIndex = getIndexByValue
lib.get_index = getIndexByValue

local function classOrServiceAlreadyExists(Name)
	return classAndServiceNameList[name] and true or false;
end

local function Class(Constructor)
	--- Provides a wrapper for new classes. 

	local newConstructor = function(...)
		local newClass = {}
		local Results = {Constructor(newClass, ...)}
		return newClass, unpack(Results)
	end

	return newConstructor
end
lib.class = Class;
lib.Class = Class;

local function isA(value, dataType)
	-- Returns if a 'value' is a specific type.  
	
	local valueType = type(value)

	if valueType == dataType then
		return true;
	elseif valueType == "number" and dataType == "int" and lib.isAnInt(value) then
		return true;
	elseif valueType == "table" and dataType == "array" and lib.isAnArray(value) then
		return true;
	elseif classList[value] == dataType then
		return true;
	elseif serviceList[value] == dataType then
		return true;
	else
		local specificType = Type.GetType(value)
		if specificType == dataType then
			return true;
		end
	end
	return false;
end
lib.isA = isA
lib.IsA = isA
lib.is_a = isA

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