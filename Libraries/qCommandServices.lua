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

local Type              = LoadCustomLibrary('Type')
local qString           = LoadCustomLibrary('qString')
local qSystems          = LoadCustomLibrary('qSystems')

local Settings          = LoadCustomLibrary('SettingsService').Settings

qSystems:Import(getfenv(0));

-- This file is basically a big hash of a ton of services the command service uses that are interalted. 

-- / Header Code --

--[[
Methods are likeThis
Variables are likeThis
classes are LikeThis
Functions are LikeThis

------------------------
-- Loading/Scheduling --
------------------------
Tabbed in parts are dependent

Library System
	Type Library
		qSystems
			qString
				AdminCommands

--]]

local lib = {}



---------------------------------
-- Command and Argument System --
---------------------------------

--[[

MakeArgumentWithParameters ( Class `Argument`, ... )
	returns: `ArgumentWithParameters`
		
Creates an `ArgumentWithParameters` class which is assigned to each command and contains the specific 
paramaters that the argument needs, such as high or low values.  

The intent of this was to allow local side scripts to have sliding values and stuff, such as humanoid 
values, but this system still does not work like that at all, which is quite disappointing.  However, 
it still allows input validation

Arguments:
	`Argument`
		The base argument 
	`...`
		Any number of arguments after this that should be whatever the base argument requires.  

Returns:
	`ArgumentWithParamter`
		The newly created object

--]]


local MakeArgumentWithParameters = class 'ArgumentWithParameters' (function(argument, baseArgument, ...) -- Each command get's it's own pseudo 'Argument' class.
	-- Throw away class to allow argument specifically. 

	VerifyArg(baseArgument, "Argument", "baseArgument");
	

	local inputArguments = {...}

	argument.name = baseArgument.name;
	argument.requiresInput = baseArgument.requiresInput;
	--argument.description = baseArgument.description;
	argument.baseArgument = baseArgument

	function argument:getArgumentFromString(stringInput, user) --> stringInput, inputArguments, user, ...
		-- Returns the argument from a string

		VerifyArg(stringInput, "string", "stringInput", not argument.requiresInput);
		VerifyArg(user, "Player", "user");
		

		return baseArgument:getArgumentFromString(stringInput, user, unpack(inputArguments));
	end
end)



local MakeArgument = class 'Argument' (function(argument, argumentSystem, argumentName, description, argumentFunction, requiresInput)
	-- A generic argument...

		-- So basically I ran into a problem with arguments. Each argument is generic, so we can have an argument for
		-- numbers, and one for other stuff, but what if we want constrained numbers? Like 3-25?  We dont' want a new argument
		-- class to be created the long way, so...

		-- So the solution was to give each command it's own argument class 'ArgumentWithParamter', which meant that there's 
		-- a lot of tables per a command. Each command has it's own table, plus one for each argument, and then another entire
		-- table per an argument. 

		-- So there's an iffyness of if we really do get a better efficiency with this system. Development time is definitly 
		-- faster after the fact, but.. eh. 


	VerifyArg(argumentSystem, "ArgumentSystem", "argumentSystem");
	VerifyArg(description, "string", "description")
	VerifyArg(argumentName, "string", "argumentName");
	VerifyArg(argumentFunction, "function", "argumentFunction")

	argument.name = argumentName;
	argument.requiresInput = requiresInput;
	argument.description = description;

	function argument:getArgumentFromString(stringInput, user, ...)
		-- Returns the argument from a string

		VerifyArg(stringInput, "string", "stringInput", not argument.requiresInput);
		VerifyArg(user, "Player", "user");

		return argumentFunction(stringInput, user, ...);
	end

	function argument:MakeSpecificArgument(...)
		-- Returns a new class 'ArgumentWithParameters'

		local NewArgumentWithParams = MakeArgumentWithParameters(argument, ...);
		return NewArgumentWithParams;
	end
end)

local Args

local ArgumentSystem = service 'ArgumentSystem' (function(argumentSystem)
	local argumentList = {}
	local argumentCount = 0;

	argumentSystem.Arguments = {}

	setmetatable(argumentSystem.Arguments, { -- Syntax hacks to get an argument. 
		__index = function(indexedTable, newIndex)
			VerifyArg(newIndex, "string", "newIndex");

			if argumentList[newIndex] then
				return function(...)
					if argumentList[newIndex] then
						local newArgumentWithParams = argumentList[newIndex]:MakeSpecificArgument(...);
						return newArgumentWithParams
					else
						error("[qCommandServices] - Argument '"..newIndex.."' does not exist");
					end
				end
			else
				error("[qCommandServices] - Could not find the argument '"..newIndex.."' listed", 2);
			end

		end;
		__newindex = function()
			error("[qCommandServices] - Can not add values to the argument System. Use the method.");
		end;
	})

	Args = argumentSystem.Arguments

	function argumentSystem:addArgument(argumentName, description, argumentFunction, requiresInput)
		-- Adds a new argument to the argument system

		VerifyArg(argumentName, "string", "argumentName")
		VerifyArg(description, "string", "description")
		VerifyArg(argumentFunction, "function", "argumentFunction")
		VerifyArg(requiresInput, "boolean", "requiresInput")

		local newArgument = MakeArgument(argumentSystem, argumentName, description, argumentFunction, requiresInput)

		argumentList[argumentName] = newArgument;
		argumentCount = argumentCount + 1;
	end

	argumentSystem.add = argumentSystem.addArgument;


	function argumentSystem:getArgumentsFromInput(arguments, input, user)
		-- Executes the arguments, and returns the arguments output in a table. 

		VerifyArg(arguments, "table", "arguments");
		VerifyArg(input, "table", "input");
		VerifyArg(user, "Player", "user");

		local inputIndex = 1;
		local newArguments = {}

		for index, argument in pairs(arguments) do
			VerifyArg(argument, "ArgumentWithParameters", "argument")

			if argument.requiresInput then
				local allOptions
				local stringInput = input[inputIndex];

				if type(stringInput) ~= "string" then
					error("[qCommandServices] - input["..inputIndex.."] should be a string, got '"..Type.getType(stringInput).."' ")
				else
					allOptions = argument:getArgumentFromString(stringInput, user);
					if type(allOptions) ~= "table" then
						error("[qCommandServices] - Expected a 'table', got a '"..Type.getType(allOptions).."' value from the argumentFunction of '"..argument.name)
					elseif #allOptions <= 0 then
						warn("[qCommandServices] - All options had 0 options, so the command won't execute")
					end
				end

				newArguments[index] = allOptions;
				inputIndex = inputIndex + 1;

			else
				local allOptions = argument:getArgumentFromString(nil, user);
				if type(allOptions) ~= "table" then
					error("[qCommandServices] - Expected a 'table', got a '"..Type.getType(allOptions).."' value from the argumentFunction of '"..argument.name)
				elseif #allOptions <= 0 then
					warn("[qCommandServices] - All options had 0 options, so the command won't execute")
				end
				newArguments[index] = allOptions;
			end
		end

		return newArguments;
	end

	function argumentSystem:getNumberOfRequiredInputArguments(arguments)
		-- Returns the number of arguments required as string input when the argument is called as from a string.  

		VerifyArg(arguments, "table", "arguments");

		local inputArgumentsRequired = 0;

		for _, argumentObject in pairs(arguments) do
			VerifyArg(argumentObject, "ArgumentWithParameters", "argumentObject")

			if (argumentObject.requiresInput) then
				inputArgumentsRequired = inputArgumentsRequired + 1;
			end
		end

		return inputArgumentsRequired;
	end
end)



local MakeCommand = class 'Command' (function(command, commandSystem, commandName, commandFunction, tags, ...)
	VerifyArg(commandSystem, "CommandSystem", "commandSystem")
	VerifyArg(commandName, "string", "commandName");
	
	local arguments = {...}

	command.tags = tags -- I think later tags can be assigned specific rolls with a string syntax like this:
	-- Description:hHello there
	-- Which would mean we can get the "Description" from the tag. THis saves us froma dding on to this massive 
	-- argument thing, as it's quite a pain to instance a new command already. 

	if tags.StringCommand == true then
		command.stringCommand = true -- Find all the arguments, and then dump the rest as a string...
	else
		command.stringCommand = false
	end
	command.commandSystem = commandSystem;
	command.name = commandName;
	command.arguments = arguments;

	command.requiredInputNumber = ArgumentSystem:getNumberOfRequiredInputArguments(arguments)
	command.totalArgumentRequired = #arguments

	--[==[
	function command:addTags(tags)
		VerifyArg(tags, "table", "tags")

		--[[for _, newTag in pairs(tags) do
			if type(newTag) ~= "string" then
				argumentError("tag", false, "string", Type.getType(newTag));
			end
			command.tags[#command.tags+1] = newTag;
		end--]]
	end--]==]

	function command:execute(...)
		-- Execute the command, given ambigius number of arguments. Not even sure why I wrap it, but probably useful for 
		-- return filtering (Through strings)

		commandFunction(...)
	end

	function command:safeExecute(...)
		-- Same as above, but in a non-error way, so we can't have errors.  Little bit of a weird hack because of Lua syntax errors. 

		local arguments = {...} -- Yeah, we have to do this. 
		Spawn(function()
			commandFunction(unpack(arguments));
		end)
	end
end)




local CommandSystem = service 'CommandSystem' (function(commandSystem)
	-- Basically it contains commands, and then you can execute them, and it'll pull the arguments from the ArgumentSystem 
	-- You CAN do overloading, but only from a # standpoint, you can have..
	--      kill/Quenty and kill
	-- Where kill/Quenty has 1 argument and kill/ has 0. However, it's impossible to distinguish between different types of input,
	-- Especially since Lua is a loose-type language (That's getting really annoying)

	local commandList = {}
	local aliasList = {} -- All the commands get added into here. So if we have this: 
	--[[

			Cmds:add("Kill", {
					"Description: Kills the player.  (Duh).";
					"Kill";
				},
				function(PlayerCharacter)
					RawKill(PlayerCharacter.Character)
				end, Args.PlayerCharacter())
				Cmds:Alias("Kill", "Die", "Murder", "Terminate", "Assassinate", "Slaughter", "keel", "k33l", "Snuff", "slay", "kl")

		Then this is what happens:
			commandList[1] = theCommandThingy

			aliasList["Kill"]        = "Kill";
			aliasList["Die"]         = "Kill";
			aliasList["Murder"]      = "Kill";
			aliasList["Terminate"]   = "Kill";
			aliasList["Assassinate"] = "Kill";
			aliasList["Slaughter"]   = "Kill";
			aliasList["keel"]        = "Kill";
			aliasList["k33l"]        = "Kill";
			aliasList["Snuff"]       = "Kill";
			aliasList["slay"]        = "Kill";
			aliasList["kl"]          = "Kill";

		Now let's say we want to add another kill command, but with only 1 argument. All those aliases will STILL work. It'll
		add the kill command into the command list. 

			commandList[2] = theCommandThingy

		And that's it. So when we're trying to execute a command, it finds the # of arguments the user gave, and then it goes ahead
		and executes the right command (The one with the right # of commands).  But Kill, Die, Murder, those aliases all point to the
		same command, so they'll act the same way. 

		So getCommand simply returns a table of commands with the same # of arguments.  Oh, and aliasList is in all lowercase.  So in 
		reality, it's...

			aliasList["kill"]        = "Kill";

		For easy indexing.

		That means, however, it's fairly easy to override access to a command in an aliasLIst. 
s
	--]]
	local aliasCount = 0
	local commandCount = 0

	function commandSystem:addNewCommand(commandName, commandTags, commandFunction, ...)
		-- Adds a new command. 
		-- Technically should accept the class 'Command', but this is better for input verification.
		-- Because we have to assign and associate to a specific command service, and then we have to check to make sure we don't have ambigius commands.

		VerifyArg(commandName, "string", "commandName");
		VerifyArg(commandTags, "table", "commandTags");
		commandName = commandName:lower()
		local otherCommands = commandSystem:getCommands(commandName)
		local newCommand = MakeCommand(commandSystem, commandName, commandFunction, commandTags, ...);
		--newCommand:addTags(commandTags);

		if otherCommands and commandTags.StringCommand == true then  -- Check to make sure there's no ambiguity in the command system for that command. 
			error("[qCommandServices] - Another command(s) by the name of '"..commandName.."' already exist, no 'stringCommand' may be registered for that name")
		elseif otherCommands then
			for _, otherCommand in pairs(otherCommands) do
				if otherCommand.requiredInputNumber == newCommand.requiredInputNumber then
					error("[qCommandServices] - Another command by the name of '"..commandName.."' already has exists, and has the same number of inputs ("..newCommand.requiredInputNumber..") leading to ambiguity")
				elseif otherCommand.stringCommand then
					error("[qCommandServices] - Another command by the name of '"..commandName.."' is stringCommand, so no new commands may be registered with this name")
				end
			end
		end

		aliasList[commandName] = commandName

		commandList[#commandList + 1] = newCommand; -- Add it to the list.  No pain. 
		commandCount = commandCount + 1; -- This is so we can come back and return a # when they ask for how many commands we have. 
	end

	commandSystem.add = commandSystem.addNewCommand; -- Aliases. :)
	commandSystem.Add = commandSystem.addNewCommand;

	function commandSystem:addNewAlias(commandName, ...)
		-- Adds a new Alias of the command with the name of 'commandName'.  And yes, the way the alias system works, aliases can be added to aliases. 

		VerifyArg(commandName, "string", "commandName")

		local commandNameNew = aliasList[commandName:lower()] -- Get the right pointer. (Get the real name of the command)

		if not commandNameNew then -- Oh dang, that command doesnt' exist?
			error("[qCommandServices] - The command '"..commandName.."' does not exist, so aliases could not be added...")
		end

		for _, aliasName in pairs({...}) do
			VerifyArg(aliasName, "string", "aliasName")

			aliasName = aliasName:lower()
			aliasCount = aliasCount + 1 -- Count the number of aliases added. 

			if aliasList[aliasName] then
				error("[qCommandServices] - A command or alias already exists with the name '"..commandName.."', so an alias could not be made.")
			end

			aliasList[aliasName] = commandNameNew
		end
	end

	commandSystem.alias = commandSystem.addNewAlias
	commandSystem.Alias = commandSystem.addNewAlias

	function commandSystem:getCommands(commandName)
		-- Returns all of the command objects that have the name 'commandName'

		VerifyArg(commandName, "string", "commandName");

		local commandNameNew = commandName:lower()
		--print(commandNameNew)
		commandNameNew = aliasList[commandNameNew] -- Get the right pointer. 

		--print("Searching for '"..tostring(commandName).."' in aliasList, got '"..tostring(commandNameNew).."'")

		if not commandNameNew then -- command doesn't exist in the aliasList, so it doesn't exist. 
			return nil;
		end

		local foundCommandList = {}

		for _, command in pairs(commandList) do
			if qString.CompareStrings(command.name, commandNameNew) then -- Use the compare string function so we get lowercase, etc. 
				foundCommandList[#foundCommandList + 1] = command;
			end
		end


		if #foundCommandList >= 1 then
			return foundCommandList;
		else
			return nil;
		end
	end

	function commandSystem:executeCommandFromString(commandString, user)
		-- Executes a command based on a string (so it may be interpritated from chat);

		VerifyArg(commandString, "string", "commandString");
		VerifyArg(user, "Player", "user", true);

		local seperatedString = qString.BreakString(commandString, Settings.commandSeperators)
		--[[
		print(commandString)
		for Index, Value in pairs(seperatedString) do
			print(Index,Value)
		end
		--]]
		local commandName = seperatedString[1]


		local oldPrint = print
		local returnLine = ""
		local didExecute = false
		local function print(...)
			for _, Item in pairs({...}) do
				oldPrint(Item)
				returnLine = returnLine..tostring(Item).." ";
			end
			returnLine = returnLine.."\n";
		end
		
		if type(commandName) == "string" then
			local possibleCommands = commandSystem:getCommands(commandName)
			if (possibleCommands) then
				local argumentInputs = #seperatedString - 1;
				local foundCommand;
				--local argumentClosness = math.huge;

				for _, possibleCommand in pairs(possibleCommands) do -- Identify the command closest too the 
					if possibleCommand.requiredInputNumber == argumentInputs then
						foundCommand = possibleCommand;
					elseif possibleCommand.stringCommand then
						foundCommand = possibleCommand
					end
				end

				if foundCommand then
					--print("[qCommandServices] - Found the command '"..commandName.."' with "..foundCommand.requiredInputNumber.." required input.")
					local newSeperatedString = {} -- Without command name...
					local commandCanExecute = true
					if foundCommand and foundCommand.stringCommand then
						-- Handle String Commands
						if #seperatedString > foundCommand.requiredInputNumber then -- Not enough arguments to execute...
							for index=2, foundCommand.requiredInputNumber do -- Shift over, but only include the arguments expected...
								newSeperatedString[index-1] = seperatedString[index];
								--print(seperatedString[index])
							end
							print("[qCommandServices] - Message: ("..tostring(foundCommand.requiredInputNumber)..") '"..tostring(qString.GetRestOfSemiTokenizedString(commandString, Settings.commandSeperators, foundCommand.totalArgumentRequired)).."' ")
							newSeperatedString[foundCommand.requiredInputNumber] = qString.GetRestOfSemiTokenizedString(commandString, Settings.commandSeperators, foundCommand.requiredInputNumber)
							print("[qCommandServices] - newSeperateString["..foundCommand.requiredInputNumber.."] = "..tostring(newSeperatedString[foundCommand.requiredInputNumber]))
						else
							print("[qCommandServices] - Could not execute, not enough arguments... ")
							commandCanExecute = false
						end
					else
						-- Handle normal commands..
						for index=2, #seperatedString do
							newSeperatedString[index-1] = seperatedString[index]; -- Shift over values in table...
						end
					end
					if commandCanExecute then -- Make sure that the above anti-overloading didnt' cancel..
						local arguments = ArgumentSystem:getArgumentsFromInput(foundCommand.arguments, newSeperatedString, user);

						if #arguments == foundCommand.totalArgumentRequired then
							print("[qCommandServices] - Executing the command '"..commandName.."' ")

							local repeatAll;

							function repeatAll(givenTable, specificIndex, ...)
								if specificIndex < 1 then
									print("[qCommandServices] - Exeucting Specific: '"..commandName.."'")
									-- Execute
									foundCommand:execute(...)
									didExecute = true
								else
									local newTable = givenTable[specificIndex]
									for index = 1, #newTable do
										repeatAll(givenTable, specificIndex-1, newTable[index], ...)
									end
								end
							end

							repeatAll(arguments, #arguments)
						else
							print("[qCommandServices] - #argumments recevied from the argument system ("..#arguments..") does not equal the number required ("..foundCommand.totalArgumentRequired..")")
						end
					else
						print("[qCommandServices] - commandCanExecute was set to false.")
					end
				else
					print("[qCommandServices] - Could not find a command with the name of '"..commandName.."'")
				end
			else
				print("[qCommandServices] - No command found w/ the name of '"..commandName.."'")
			end
		else
			argumentError("commandName", false, "string", Type.getType(commandName))
		end

		return returnLine, didExecute;
	end

	function commandSystem:getNumberOfCommands()
		return commandCount;
	end

	function commandSystem:getNumberOfAlias()
		return aliasCount;
	end

	function commandSystem:getComands()
		return commandList
	end

	function commandSystem:getAliasCountForCommand(CommandName)
		local Count = 0
		CommandName = CommandName:lower()
		for _, CommandAliasName in pairs(aliasList) do
			if CommandAliasName == CommandName then
				Count = Count+1
			end
		end
		return Count
	end

	function commandSystem:getAlias(CommandName)
		local Alias = {}
		CommandName = CommandName:lower()
		for AliasName, CommandAliasName in pairs(aliasList) do
			if CommandAliasName == CommandName then
				Alias[#Alias+1] = AliasName
			end
		end
		return Alias
	end
end)

-----------------
-- Exececution --
-----------------

lib.ArgumentSystem = ArgumentSystem;
lib.CommandSystem = CommandSystem;

lib.ArgSys = ArgumentSystem;
lib.Args = ArgumentSystem.Arguments;
lib.Cmds = CommandSystem;

NevermoreEngine.RegisterLibrary('qCommandServices', lib);