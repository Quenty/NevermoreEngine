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

local Settings = service 'Settings' (function(settings)
	local settingsCache = {}
	local settingType = {}

	local canAddNewSettings = true;
	local canChangeCurrentSettings = true;

	setmetatable(settings, {
		__newindex = function(table, index, value)
			VerifyArg(index, "string", "index")

			if value == nil then
				error("You can't set a value in settings to nil");
			end

			if settingsCache[index] == nil then
				if canAddNewSettings then
					settingType[index] = type(value)
					settingsCache[index] = value;
				else
					error("You can't add any new settings to settings")
				end
			else
				if type(value) ~= settingType[index] then
					error("The datatype supplied in the settings is wrong!")
					--argumentError(value, false, settingType[index], Type.getType(index))
				else
					settingsCache[index] = value;
				end
			end
		end;
		__index = function(table, index)
			VerifyArg(index, "string", "index")
			if settingsCache[index] ~= nil then
				return settingsCache[index];
			else
				error("The settings '"..index.."' does not exist");
			end
		end;
		__tostring = function()
			return tostring(#settingsCache)
		end;
		__metatable = false;
	})
end)

Settings.commandsAreInvisibleOnPseudoChat = true -- Do commands show up in pseudo chat?
Settings.commandSeperators = {"/", " ", "\\", "!", ">", "<", ";", ":"} 
--[[
	kill/Quenty
	kill Quenty
	kill!Quenty
	kill\Quenty

	Also note that the breakString system ignores empty strings when it's adding stuff to it's internal list. 
	In this way, we can also do stuff like this:

	!kill Quenty

--]]
Settings.moreArguments = {",", ";"}
--[[
	kill Quenty,bob104810,JulienDethurens
	kill Quenty;bob104810,JulienDethurens

	damage Quenty;bob104810 35,10
		--> Damages Quenty and bob104810 for 35 damage, then damages them for both 10 damage
--]]
Settings.specificGroups = {"."}
--[[
	kill Quenty,Group.10582.35,Badge.3634,Item.36346
		--> Kills Quenty, Anyone in group ID 10582 with a rank of 35, anyone who owns the Badge w/ the ID 3634 and 
			anyone who owns the Item with the ID 36346

		    The script breaks the chat apart like this:

		    kill
		    	Quenty
		    	Group
		    		10481
		    		35
				Badge
					3634
				Item
					36346

			It then searches for a 'PlayerReference' for the name of 'Quenty', 'Group', 'Badge', or 'Item', and then
			if it finds the itme, uses the code within to get a list of Players.  

			It breaks apart these using the tables of stuff, which default in "." or ";", but if these are changed 
			inadvertantly to the same thing by a noob, then it  may disallow the references. For example, say that the
			moreArguments receives the character '.' in it's list.  This would be bad, because a string like this:

				kill Quenty,Group.123456

			Would break up like this:

			kill
				Quenty
				Group
				123456

			And then search for those.  
--]]
Settings.KeyGroups = {
	["Staff"] = "Quenty;"


}
--[[
	Based off of Corecii's KeyGroup system.  It is quite probable that it will be revised later on. 

--]]
--Settings.Bin = nil; -- Resource bin. 

Settings.RobloxAdmins = {'Sorcus', 'Shedletsky', 'Telamon', 'Tarabyte', 'StickMasterLuke', 'OnlyTwentyCharacters', 'FusRoblox', 'SolarCrane', 
		'HotThoth', 'JediTkacheff', 'Builderman', 'Brighteyes', 'ReeseMcblox', 'GemLocker', 'GongfuTiger', 'Erik.Cassel', 'Matt Dusek', 'Keith',
		'Totbl', 'LordRugDump', 'David.Baszucki', 'Dbapostle', 'DaveYorkRBX', 'nJay', 'OstrichSized', 'TobotRobot', 'twberg', 'ROBLOX', 'RBAdam', 'Doughtless',
		'Anaminus', 'Stravant', 'Merely'
	};

Settings.Initiated = false; -- Will be set to true once settings have been configured. 

lib.Settings = Settings

NevermoreEngine.RegisterLibrary('SettingsService', lib);