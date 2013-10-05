while not _G.NevermoreEngine do wait(0) end

local Players                 = Game:GetService('Players')
local StarterPack             = Game:GetService('StarterPack')
local StarterGui              = Game:GetService('StarterGui')
local Lighting                = Game:GetService('Lighting')
local ServerStorage           = game:GetService("ServerStorage")
local ReplicatedStorage       = game:GetService("ReplicatedStorage")
local Debris                  = Game:GetService('Debris')
local Teams                   = Game:GetService('Teams')
local BadgeService            = Game:GetService('BadgeService')
local InsertService           = Game:GetService('InsertService')
local Terrain                 = Workspace.Terrain
local TestService             = game:GetService('TestService')

local NevermoreEngine         = _G.NevermoreEngine
local LoadCustomLibrary       = NevermoreEngine.LoadLibrary;

local RbxUtility              = LoadLibrary('RbxUtility')
local RbxGui                  = LoadLibrary('RbxGui')

local Type                    = LoadCustomLibrary('Type')
local lib                     = {}

local classList               = {}
local serviceList             = {}
local classAndServiceNameList = {}

local qSystemsBin = ReplicatedStorage:FindFirstChild(NevermoreEngine.SystemName)
assert(qSystemsBin, "[QuentySupportSystem] - qSystemsBin could not be identified")

local ResourceBin = qSystemsBin:FindFirstChild("Resources");
assert(ResourceBin, "[QuentySupportSystem] - ResourceBin could not be identified")

local LibraryBin = ResourceBin:FindFirstChild("Libraries");
assert(LibraryBin, "[QuentySupportSystem] - LibraryBin could not be identified")

local ClientBin = qSystemsBin:FindFirstChild("Client");
assert(ClientBin, "[QuentySupportSystem] - ClientBin could not be identified")

local ServerBin = qSystemsBin:FindFirstChild("Server");
assert(ServerBin, "[QuentySupportSystem] - ServerBin could not be identified")
local PlayerDataBin = ResourceBin:FindFirstChild("PlayerData") or (function() 
			local Bin = Instance.new("Configuration", ResourceBin) 
			Bin.Name = "PlayerData";
		return Bin 
	end)();

assert(qSystemsBin, "[qSystems] - qSystemsBin could not be identified")
assert(ResourceBin, "[qSystems] - ResourceBin could not be identified")
assert(LibraryBin, "[qSystems] - LibraryBin could not be identified")
assert(ClientBin, "[qSystems] - ClientBin could not be identified")
assert(ServerBin, "[qSystems] - ServerBin could not be identified")

lib.qSystemsBin = qSystemsBin
lib.ResourceBin = ResourceBin
lib.LibraryBin = LibraryBin
lib.ClientBin = ClientBin
lib.ServerBin = ServerBin
lib.PlayerDataBin = PlayerDataBin

lib.Settings = {}

--setmetatable(serviceList, {__mode = "k"})
setmetatable(classList, {__mode = "k"})

--[[
lib.createSignal = RbxUtility.CreateSignal
lib.CreateSignal = RbxUtility.CreateSignal
lib.create_signal = RbxUtility.CreateSignal--]]

local function CreateSignal() -- Ripped directly from RbxUtility. Modified for :Destroy()
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
	end

	function this:Destroy()
		mBindableEvent:Destroy()
	end

	return this
end
lib.CreateSignal = CreateSignal
lib.createSignal = CreateSignal
lib.create_signal = CreateSignal

local function argumentError(argumentName, optional, expectedType, gottenValue, contextLevel)
	-- Generates a nice classy error that informs people nicely

	if optional then
		error("bad '"..argumentName.."' optional argument ("..expectedType.." expected, got "..gottenValue..")", contextLevel or 2)
	else
		error("bad '"..argumentName.."' argument ("..expectedType.." expected, got "..gottenValue..")", contextLevel or 2)
	end
end
lib.argumentError = argumentError
lib.ArgumentError = argumentError
lib.argument_error = argumentError




local function verifyArg(value, dataType, argumentName, optional, contextLevel)
	-- Verifies that an arguments type is as expected. 

	contextLevel = contextLevel or 0

	if type(dataType) ~= "string" then
		argumentError("dataType", false, "string", Type.getType(dataType), 2 + contextLevel)
	end

	if type(argumentName) ~= "string" then
		argumentError("argumentName", false, "string", Type.getType(argumentName), 2 + contextLevel)
	end

	local valueToNumber = tonumber(value)
	local valueTypeSpecific = Type.getType(value)
	local valueType = type(value)

	if optional and value == nil then
		return value
	elseif valueType == dataType then
		return value
	elseif valueTypeSpecific == dataType then
		return value
	elseif Type.isAnInstance(value) and game.IsA(value, dataType) then
		return value
	elseif dataType == "string" and valueToNumber then
		return valueToNumber
	elseif dataType == "string" and valueType == "number" then
		return tostring(value)
	elseif classList[value] == dataType or serviceList[value] == dataType then
		return value;
	else
		argumentError(argumentName, optional, dataType, valueTypeSpecific, 3 + contextLevel)
	end
end
lib.verifyArg = verifyArg
lib.VerifyArg = verifyArg
lib.verify_arg = verifyArg

local function roundNumber(number, divider)
	--verifyArg(number, "number", "number")
	--verifyArg(divider, "number", "divider", true)

	divider = divider or 1

	return (math.floor((number/divider)+0.5)*divider)
end
lib.roundNumber = roundNumber
lib.RoundNumber = roundNumber
lib.round_number = roundNumber


local function warn(warningText)
	-- Generates a safe 'error', so you get nice red warning text...
	--verifyArg(warningText, "string", "warningText")

	Spawn(function()
		TestService:Warn(false, warningText)
	end)

end
lib.warn = warn;
lib.Warn = warn;


local function modify(instance, values)
	-- Modifies an instance by using a table.  

	--verifyArg(instance, "Instance", "instance")
	--verifyArg(values, "table", "values")

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

	--verifyArg(type, "string", "type")

	return function(values)
		verifyArg(values, "table", "values")

		local newInstance = Instance.new(type)
		return modify(newInstance, values)
	end
end
lib.make = make;
lib.Make = make;


local function waitForChild(parent, name)
	-- Waits for a child to appear.   
	-- Useful when ROBLOX lags out, and doesn't replicate quickly.

	--verifyArg(parent, "Instance", "parent", false, 1)
	--verifyArg(name, "string", "name", false, 1)

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

local callOnChildren;

local function callOnChildren(instance, functionToCall)
	-- Calls a function on each of the children of a certain object, using recursion.  

	--verifyArg(instance, "Instance", "instance")
	--verifyArg(functionToCall, "function", "functionToCall")

	functionToCall(instance)

	for _, child in next, instance:GetChildren() do
		callOnChildren(child, functionToCall)
	end
end
lib.callOnChildren = callOnChildren
lib.CallOnChildren = callOnChildren
lib.call_on_children = callOnChildren


local function getNearestParent(instance, className)
	-- Returns the nearest parent of a certain class, or returns nil

	--verifyArg(instance, "Instance", "instance")
	--verifyArg(className, "string", "className")

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

	--verifyArg(descendant, "Instance", "descendant");
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
	return player and player:IsA("Player") 
		and player:FindFirstChild("PlayerGui")
		and player:FindFirstChild("Backpack") 
		and player:FindFirstChild("StarterGear")
		and player.PlayerGui:IsA("PlayerGui")
		and player.Backpack:IsA("Backpack") 
		and player.StarterGear:IsA("StarterGear")
end
lib.checkPlayer = checkPlayer
lib.CheckPlayer = checkPlayer
lib.check_player = checkPlayer


local function checkCharacter(player)
	local character = player.Character;

	if character and checkPlayer(player) then
		

		return character:FindFirstChild("Humanoid") 
			and character:FindFirstChild("Torso") 
			and character:FindFirstChild("Head") 
			and character.Humanoid:IsA("Humanoid")
			and character.Head:IsA("BasePart")
			and character.Torso:IsA("BasePart");
	end

	return nil;
end
lib.checkCharacter = checkCharacter
lib.CheckCharacter = checkCharacter
lib.check_character = checkCharacter


local function getIndexByValue(values, value)
	--verifyArg(values, "table", "values")

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

local function Class(className)
	if classOrServiceAlreadyExists(className) then
		error("A service or class of the name of '"..className.."' already exists", 2)
	end

	classAndServiceNameList[className] = true;

	return function (constructor)
		local newConstructor = function(...)
			local newClass = {}
			classList[newClass] = className;
			constructor(newClass, ...)
			return newClass
		end

		--getfenv(0)["Make"..className] = newConstructor
		--getfenv(0)["make"..className] = newConstructor
		--getfenv(0)["make_"..className] = newConstructor
		return newConstructor
	end
end
lib.class = Class;
lib.Class = Class;

local function Service(serviceName)
	if classOrServiceAlreadyExists(serviceName) then
		error("A service or class of the name of '"..serviceName.."' already exists", 2)
	end

	classAndServiceNameList[serviceName] = true;

	local definition = {}
	--getfenv(0)[serviceName] = definition;
	return function (constructor)
		serviceList[definition] = serviceName;
		constructor(definition)
		return definition;
	end
end
lib.service = Service;
lib.Service = Service;

local function IsAService(potentialService)
	if serviceList[potentialService] then
		return true;
	end
	return false;
end
lib.isAService = IsAService;
lib.is_a_service = IsAService;
lib.IsAService = IsAService;

local function IsAClass(potentialClass)
	if classList[potentialClass] then
		return true;
	end
	return false;
end
lib.isAClass = IsAClass;
lib.IsAClass = IsAClass;
lib.is_a_class = IsAClass;

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

NevermoreEngine.RegisterLibrary('qSystems', lib)